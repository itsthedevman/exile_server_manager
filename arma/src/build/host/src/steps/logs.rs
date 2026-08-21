use std::{
    collections::HashMap,
    path::PathBuf,
    sync::{atomic::Ordering, mpsc, Arc},
    thread,
    time::{Duration, Instant},
};

use colored::Colorize;

use crate::{
    context::InstanceContext,
    display::color,
    error::BuildResult,
    target::{Target, LOG_FRAME_SEPARATOR},
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
/// Each server is polled by its own thread, because one server's round-trip should not hold up the others. The threads only render lines; printing stays on this thread so that output from
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
        let target = ictx.target.clone();
        let server_id = ictx.instance.server_id.clone();
        let server_color = LABEL_COLORS[index % LABEL_COLORS.len()];
        let server_path = ictx.server_path().to_path_buf();

        thread::spawn(move || {
            watch_server(target, server_id, server_color, server_path, sender);
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
    target: Arc<dyn Target>,
    server_id: String,
    server_color: (u8, u8, u8),
    server: PathBuf,
    sender: mpsc::Sender<LogLine>,
) {
    // server.log is Arma's own logFile from config.cfg, and is the only one named here: it is created on
    // start and never moves. Everything else is discovered, including @esm/log, so the updater's log gets
    // followed on the same terms as the extension's without either being listed.
    let fixed = vec![server.join("server_profile/server.log")];
    let rpt_dir = server.join("server_profile");
    let extdb_dir = server.join("@exileserver/logs");
    let esm_log_dir = server.join("@esm/log");

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
            discovered = target.discover_logs(&rpt_dir, &[&extdb_dir, &esm_log_dir]);
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

        if let Some(results) = target
            .read_appended(&all_files, &offsets)
            .and_then(|raw| parse_frames(&raw))
        {
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

        // Sleep only the remainder of the poll interval so the round-trip doesn't add on top of the sleep.
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

/// Split framed [`Target::read_appended`] output into `(path, new content, new size)` per file.
///
/// The size is split off the right rather than the left, which is what lets a Windows path keep its drive
/// letter: `C:\\arma3server\\foo.rpt:12345` has two colons and only the last one separates anything.
fn parse_frames(raw: &str) -> Option<Vec<(PathBuf, String, u64)>> {
    let prefix = format!("{LOG_FRAME_SEPARATOR}:");

    let mut results = Vec::new();
    let mut current_path: Option<PathBuf> = None;
    let mut current_size: u64 = 0;
    let mut current_lines: Vec<&str> = Vec::new();

    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix(&prefix) {
            if let Some(path) = current_path.take() {
                results.push((path, current_lines.join("\n"), current_size));
                current_lines.clear();
            }

            let mut parts = rest.rsplitn(2, ':');
            let size = parts.next().unwrap_or("0");
            let path = parts.next().unwrap_or("");

            current_path = Some(PathBuf::from(path));
            current_size = size.trim().parse().unwrap_or(0);
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

#[cfg(test)]
mod tests {
    use super::parse_frames;
    use crate::target::LOG_FRAME_SEPARATOR;

    #[test]
    fn parses_a_windows_path_keeping_its_drive_letter() {
        let raw = format!(
            "{LOG_FRAME_SEPARATOR}:C:\\arma3server\\server_profile\\foo.rpt:42\nfirst\nsecond\n"
        );

        let parsed = parse_frames(&raw).expect("one frame");
        assert_eq!(parsed.len(), 1);

        let (path, content, size) = &parsed[0];
        assert_eq!(path.display().to_string(), "C:\\arma3server\\server_profile\\foo.rpt");
        assert_eq!(content, "first\nsecond");
        assert_eq!(*size, 42);
    }

    #[test]
    fn splits_several_files_in_one_batch() {
        let raw = format!(
            "{LOG_FRAME_SEPARATOR}:/arma3server/a.log:3\naaa\n\
             {LOG_FRAME_SEPARATOR}:/arma3server/b.log:5\nbbbbb\n"
        );

        let parsed = parse_frames(&raw).expect("two frames");
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0].0.display().to_string(), "/arma3server/a.log");
        assert_eq!(parsed[1].0.display().to_string(), "/arma3server/b.log");
        assert_eq!(parsed[1].1, "bbbbb");
    }

    #[test]
    fn nothing_framed_is_nothing_to_print() {
        assert!(parse_frames("").is_none());
        assert!(parse_frames("noise with no frame\n").is_none());
    }
}
