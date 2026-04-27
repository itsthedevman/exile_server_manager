use std::{
    collections::HashMap,
    path::PathBuf,
    process::Command,
    thread,
    time::{Duration, Instant},
};

use colored::Colorize;

use crate::{
    context::BuildContext,
    display::color,
    error::BuildResult,
    ARMA_CONTAINER,
};

const POLL_MS: u64 = 125;
const HEARTBEAT_SECS: u64 = 5;
const SCAN_SECS: u64 = 3; // re-check for new dynamic files (RPT, extdb)

// Colors cycled per-file for the label column
const LABEL_COLORS: [(u8, u8, u8); 5] = [
    color::BLUE,
    color::GREEN,
    color::YELLOW,
    color::PURPLE,
    color::STEEL,
];

const LABEL_WIDTH: usize = 5;
const LINE_NO_WIDTH: usize = 5;

struct FileState {
    offset: u64,
    line_no: u64,
    label: String,
    color_idx: usize,
}

pub fn stream_logs(ctx: &mut BuildContext) -> BuildResult {
    let dim = color::DIM;
    let steel = color::STEEL;

    println!(
        "\n  {} {}",
        "│".truecolor(steel.0, steel.1, steel.2),
        "Streaming logs  (CTRL-C to stop)"
            .truecolor(dim.0, dim.1, dim.2)
            .italic(),
    );
    println!();

    let server = ctx.target.server_path().to_path_buf();
    // server.log: Arma's logFile from config.cfg
    // esm.log:    ESM extension log
    // *.rpt files and extdb logs are discovered dynamically
    let fixed = vec![
        server.join("server_profile/server.log"),
        server.join("@esm/log/esm.log"),
    ];
    let rpt_dir = server.join("server_profile");
    let extdb_dir = server.join("@exileserver/logs");

    let mut file_state: HashMap<PathBuf, FileState> = HashMap::new();
    let mut color_counter: usize = 0;
    let mut discovered: Vec<PathBuf> = Vec::new();
    let mut last_heartbeat =
        Instant::now() - Duration::from_secs(HEARTBEAT_SECS + 1);
    let mut last_scan =
        Instant::now() - Duration::from_secs(SCAN_SECS + 1);
    let mut saw_output = false;

    loop {
        if crate::CTRL_C_RECEIVED.load(std::sync::atomic::Ordering::SeqCst) {
            break;
        }

        let iter_start = Instant::now();

        // Periodically re-scan for newly created RPT / extdb files
        if last_scan.elapsed().as_secs() >= SCAN_SECS {
            discovered = discover_files(ARMA_CONTAINER, &rpt_dir, &extdb_dir);
            last_scan = Instant::now();
        }

        let all_files: Vec<&PathBuf> = fixed
            .iter()
            .chain(discovered.iter())
            .collect();

        // Extract current offsets for batch_read
        let offsets: HashMap<PathBuf, u64> = file_state
            .iter()
            .map(|(k, v)| (k.clone(), v.offset))
            .collect();

        if let Some(results) = batch_read(ARMA_CONTAINER, &all_files, &offsets) {
            for (path, content, new_size) in results {
                // Assign a label+color the first time we see this file
                let next_color = color_counter;
                let state = file_state.entry(path.clone()).or_insert_with(|| {
                    color_counter += 1;
                    FileState {
                        offset: 0,
                        line_no: 0,
                        label: make_label(&path),
                        color_idx: next_color % LABEL_COLORS.len(),
                    }
                });

                state.offset = new_size;
                for line in content.lines() {
                    if !line.trim().is_empty() {
                        saw_output = true;
                        state.line_no += 1;
                        print_log_line(
                            &state.label,
                            LABEL_COLORS[state.color_idx],
                            state.line_no,
                            line,
                        );
                    }
                }
            }
        }

        if !saw_output && last_heartbeat.elapsed().as_secs() >= HEARTBEAT_SECS {
            println!(
                "{}",
                "  · waiting for server…".truecolor(dim.0, dim.1, dim.2).italic()
            );
            last_heartbeat = Instant::now();
        }

        // Sleep only the remainder of the poll interval so the docker exec
        // round-trip doesn't add on top of the sleep.
        let elapsed = iter_start.elapsed();
        let target = Duration::from_millis(POLL_MS);
        if elapsed < target {
            thread::sleep(target - elapsed);
        }
    }

    Ok(())
}

/// Derive a short display label from a file path.
fn make_label(path: &PathBuf) -> String {
    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
    let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
    let path_str = path.to_string_lossy();

    if ext == "rpt" {
        return "rpt".into();
    }

    // extDB logs live under @exileserver/
    if path_str.contains("exileserver") || path_str.contains("extdb") {
        return "extdb".into();
    }

    // Arma's logFile (server.log)
    if stem == "server" {
        return "arma".into();
    }

    // Truncate anything else to LABEL_WIDTH
    stem.chars().take(LABEL_WIDTH).collect()
}

/// Discover dynamic log files (RPT in server_profile, logs in extdb dir) via
/// a single docker exec to avoid two round-trips per scan cycle.
fn discover_files(
    container: &str,
    rpt_dir: &PathBuf,
    extdb_dir: &PathBuf,
) -> Vec<PathBuf> {
    let cmd = format!(
        "find '{rpt}' -maxdepth 1 -type f -name '*.rpt' 2>/dev/null; \
         find '{ext}' -type f -name '*.log' 2>/dev/null",
        rpt = rpt_dir.display(),
        ext = extdb_dir.display(),
    );

    let output = match Command::new("docker")
        .args(["exec", container, "/bin/bash", "-c", &cmd])
        .output()
    {
        Ok(o) => o,
        Err(_) => return vec![],
    };

    String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter(|l| !l.trim().is_empty())
        .map(PathBuf::from)
        .collect()
}

/// Run one `docker exec` that reads new bytes from every file and returns
/// `(path, new_content, new_file_size)` tuples.
fn batch_read(
    container: &str,
    files: &[&PathBuf],
    offsets: &HashMap<PathBuf, u64>,
) -> Option<Vec<(PathBuf, String, u64)>> {
    if files.is_empty() {
        return None;
    }

    let sep = "__ESM_FILE__";
    let script: String = files
        .iter()
        .map(|path| {
            let offset = offsets.get(*path).copied().unwrap_or(0);
            let p = path.display();
            format!(
                "if [ -f '{p}' ]; then \
                    _sz=$(wc -c < '{p}' 2>/dev/null || echo 0); \
                    if [ \"$_sz\" -gt {offset} ]; then \
                        printf '{sep}:%s:%s\\n' '{p}' \"$_sz\"; \
                        tail -c +{skip} '{p}'; \
                        printf '\\n'; \
                    fi; \
                fi;",
                skip = offset + 1,
            )
        })
        .collect();

    let output = Command::new("docker")
        .args(["exec", container, "/bin/bash", "-c", &script])
        .output()
        .ok()?;

    let raw = String::from_utf8_lossy(&output.stdout);
    if raw.trim().is_empty() {
        return None;
    }

    let mut results = Vec::new();
    let mut current_path: Option<PathBuf> = None;
    let mut current_size: u64 = 0;
    let mut current_lines: Vec<&str> = Vec::new();

    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix(&format!("{sep}:")) {
            if let Some(path) = current_path.take() {
                results.push((path, current_lines.join("\n"), current_size));
                current_lines.clear();
            }
            let mut parts = rest.rsplitn(2, ':');
            let size_str = parts.next().unwrap_or("0");
            let path_str = parts.next().unwrap_or("");
            current_path = Some(PathBuf::from(path_str));
            current_size = size_str.parse().unwrap_or(0);
        } else if current_path.is_some() {
            current_lines.push(line);
        }
    }
    if let Some(path) = current_path {
        results.push((path, current_lines.join("\n"), current_size));
    }

    if results.is_empty() { None } else { Some(results) }
}

fn print_log_line(
    label: &str,
    label_color: (u8, u8, u8),
    line_no: u64,
    content: &str,
) {
    use common::HIGHLIGHTS;

    let steel = color::STEEL;
    let dim = color::DIM;

    let padded_label = format!("{:>width$}", label, width = LABEL_WIDTH);
    let padded_no = format!("{:>width$}", line_no, width = LINE_NO_WIDTH);

    let highlight = HIGHLIGHTS.iter().find(|h| h.regex.is_match(content));
    let styled_content = if let Some(h) = highlight {
        content.truecolor(h.color[0], h.color[1], h.color[2]).bold().to_string()
    } else {
        content.to_string()
    };

    println!(
        "  {}:{} {} {}",
        padded_label.truecolor(label_color.0, label_color.1, label_color.2).bold(),
        padded_no.truecolor(dim.0, dim.1, dim.2),
        "│".truecolor(steel.0, steel.1, steel.2),
        styled_content,
    );
}
