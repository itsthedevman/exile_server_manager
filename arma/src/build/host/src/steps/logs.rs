use std::{
    collections::HashMap,
    path::PathBuf,
    process::Command,
    sync::{atomic::Ordering, mpsc},
    thread,
    time::{Duration, Instant},
};

use colored::Colorize;

use crate::{
    context::InstanceContext,
    display::color,
    error::BuildResult,
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

/// One rendered log line on its way from a server's watcher thread to the printer.
struct LogLine {
    server_id: String,
    server_color: (u8, u8, u8),
    label: String,
    label_color: (u8, u8, u8),
    line_no: u64,
    content: String,
}

/// Tail every running server at once, printing their lines to one stream as they arrive.
///
/// Each server is polled by its own thread, because a `docker exec` round-trip against one container should
/// not hold up the others. The threads only render lines; printing stays on this thread so that output from
/// several servers can't interleave mid-line.
pub fn stream_logs(contexts: &[InstanceContext]) -> BuildResult {
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

    // With one server the name adds nothing to every line; with several it is the only way to tell them
    // apart. Pad to the longest name so the columns after it stay aligned.
    let server_width = if contexts.len() > 1 {
        contexts
            .iter()
            .map(|ictx| ictx.instance.server_id.len())
            .max()
            .unwrap_or(0)
    } else {
        0
    };

    let (sender, receiver) = mpsc::channel::<LogLine>();

    for (index, ictx) in contexts.iter().enumerate() {
        let sender = sender.clone();
        let container = ictx.container();
        let server_id = ictx.instance.server_id.clone();
        let server_color = LABEL_COLORS[index % LABEL_COLORS.len()];
        let server_path = ictx.server_path().to_path_buf();

        thread::spawn(move || {
            watch_server(container, server_id, server_color, server_path, sender);
        });
    }

    // The watchers each hold a clone; this one would otherwise keep the channel open forever.
    drop(sender);

    let mut last_heartbeat = Instant::now() - Duration::from_secs(HEARTBEAT_SECS + 1);
    let mut saw_output = false;

    loop {
        if crate::CTRL_C_RECEIVED.load(Ordering::SeqCst) {
            break;
        }

        match receiver.recv_timeout(Duration::from_millis(POLL_MS)) {
            Ok(line) => {
                saw_output = true;
                print_log_line(&line, server_width);
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => break,
        }

        if !saw_output && last_heartbeat.elapsed().as_secs() >= HEARTBEAT_SECS {
            println!(
                "{}",
                "  · waiting for server…".truecolor(dim.0, dim.1, dim.2).italic()
            );
            last_heartbeat = Instant::now();
        }
    }

    Ok(())
}

/// Poll one server's log files, sending each new line to the printer.
fn watch_server(
    container: String,
    server_id: String,
    server_color: (u8, u8, u8),
    server: PathBuf,
    sender: mpsc::Sender<LogLine>,
) {
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
    let mut last_scan = Instant::now() - Duration::from_secs(SCAN_SECS + 1);

    loop {
        if crate::CTRL_C_RECEIVED.load(Ordering::SeqCst) {
            return;
        }

        let iter_start = Instant::now();

        // Periodically re-scan for newly created RPT / extdb files
        if last_scan.elapsed().as_secs() >= SCAN_SECS {
            discovered = discover_files(&container, &rpt_dir, &extdb_dir);
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

        if let Some(results) = batch_read(&container, &all_files, &offsets) {
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
                    if line.trim().is_empty() {
                        continue;
                    }

                    state.line_no += 1;
                    let sent = sender.send(LogLine {
                        server_id: server_id.clone(),
                        server_color,
                        label: state.label.clone(),
                        label_color: LABEL_COLORS[state.color_idx],
                        line_no: state.line_no,
                        content: line.to_string(),
                    });

                    // The printer has gone away, so there is nobody left to write for.
                    if sent.is_err() {
                        return;
                    }
                }
            }
        }

        // Sleep only the remainder of the poll interval so the docker exec
        // round-trip doesn't add on top of the sleep.
        let elapsed = iter_start.elapsed();
        let target = Duration::from_millis(POLL_MS);
        if elapsed < target {
            thread::sleep(target - elapsed);
        }
    }
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

/// A `server_width` of zero means a single-server run, where the name is left off entirely.
fn print_log_line(line: &LogLine, server_width: usize) {
    use common::HIGHLIGHTS;

    let steel = color::STEEL;
    let dim = color::DIM;

    let padded_label = format!("{:>width$}", line.label, width = LABEL_WIDTH);
    let padded_no = format!("{:>width$}", line.line_no, width = LINE_NO_WIDTH);

    let highlight = HIGHLIGHTS.iter().find(|h| h.regex.is_match(&line.content));
    let styled_content = if let Some(h) = highlight {
        line.content
            .truecolor(h.color[0], h.color[1], h.color[2])
            .bold()
            .to_string()
    } else {
        line.content.clone()
    };

    let server_prefix = if server_width > 0 {
        let padded = format!("{:<width$}", line.server_id, width = server_width);
        format!(
            "{} ",
            format!("[{padded}]")
                .truecolor(line.server_color.0, line.server_color.1, line.server_color.2)
                .bold()
        )
    } else {
        String::new()
    };

    println!(
        "  {}{}:{} {} {}",
        server_prefix,
        padded_label
            .truecolor(line.label_color.0, line.label_color.1, line.label_color.2)
            .bold(),
        padded_no.truecolor(dim.0, dim.1, dim.2),
        "│".truecolor(steel.0, steel.1, steel.2),
        styled_content,
    );
}
