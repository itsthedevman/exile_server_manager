use std::{
    io::{self, Write},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex, MutexGuard,
    },
    thread,
    time::Duration,
};

use colored::Colorize;

use crate::display::{color, dot_leader, tree_branch, tree_pipe};

const FRAMES: &[char] = &['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
const STEP_WIDTH: usize = 36;

// ─── Simple Spinner ──────────────────────────────────────────────────────────

/// Animated braille spinner for a single-line build step.
pub struct Spinner {
    label: String,
    stop: Arc<AtomicBool>,
    handle: Option<thread::JoinHandle<()>>,
}

impl Spinner {
    pub fn start(label: impl Into<String>) -> Self {
        let label = label.into();
        let stop = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop);
        let label_clone = label.clone();

        Self::print_frame(&label_clone, FRAMES[0]);

        let handle = thread::spawn(move || {
            let mut idx = 1usize;
            while !stop_clone.load(Ordering::Relaxed) {
                thread::sleep(Duration::from_millis(80));
                if stop_clone.load(Ordering::Relaxed) {
                    break;
                }
                Self::print_frame(&label_clone, FRAMES[idx % FRAMES.len()]);
                idx = idx.wrapping_add(1);
            }
        });

        Spinner { label, stop, handle: Some(handle) }
    }

    pub fn done(mut self) {
        self.stop_thread();
        self.print_result(true);
    }

    pub fn fail(mut self) {
        self.stop_thread();
        self.print_result(false);
    }

    fn stop_thread(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            let _ = h.join();
        }
    }

    fn print_result(&self, success: bool) {
        let green = color::GREEN;
        let red = color::RED;
        let dots = dot_leader(&self.label, STEP_WIDTH);
        let (icon, result_color, status) = if success {
            ('✓', green, "done")
        } else {
            ('✗', red, "failed")
        };
        print!(
            "\r  {} {}{} {}\n",
            icon.to_string().truecolor(result_color.0, result_color.1, result_color.2).bold(),
            self.label.bold(),
            dots,
            status.truecolor(result_color.0, result_color.1, result_color.2),
        );
        let _ = io::stdout().flush();
    }

    fn print_frame(label: &str, frame: char) {
        let yellow = color::YELLOW;
        let dots = dot_leader(label, STEP_WIDTH);
        print!(
            "\r  {} {}{}",
            frame.to_string().truecolor(yellow.0, yellow.1, yellow.2),
            label.bold(),
            dots,
        );
        let _ = io::stdout().flush();
    }
}

impl Drop for Spinner {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            let _ = h.join();
        }
    }
}

// ─── Multi-step Spinner ───────────────────────────────────────────────────────

/// How many lines sit below a [`MultiSpinner`]'s header, and the lock every write to that region takes.
///
/// A mutex rather than an atomic because the count and the cursor are one piece of state. The animation thread
/// reads the count, jumps up by it, rewrites the header and jumps back; a line printed anywhere in the middle of
/// that leaves the cursor somewhere the count no longer describes, and the header lands on top of it.
type LineCount = Arc<Mutex<usize>>;

fn lines(count: &LineCount) -> MutexGuard<'_, usize> {
    // A panic mid-print is a build-tool crash either way, and `stop_thread` runs from `Drop`: treating the
    // poison as fatal there would turn that crash into an abort with nothing useful printed.
    count.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Prints sub-process output below a [`MultiSpinner`]'s header, keeping the header's line count in step.
///
/// Printing and counting are deliberately one operation. They used to be two, and every caller had to remember
/// the second: `pack_addons` printed ten PBO lines without it, so the header animation spent the rest of the
/// step redrawing itself ten lines below where the header actually was.
#[derive(Clone)]
pub struct SubLines {
    count: LineCount,
}

impl SubLines {
    pub fn print(&self, line: &str) {
        let mut count = lines(&self.count);
        println!("{}{}", tree_pipe(), line.trim_end());
        *count += 1;
    }
}

/// Spinner for steps that stream sub-step output below a header line.
///
/// The header line animates in a background thread by using ANSI cursor-up to
/// rewrite it without disturbing the sub-step lines that have been printed below.
pub struct MultiSpinner {
    label: String,
    /// Number of lines printed below the header (sub-steps).
    lines_below: LineCount,
    stop: Arc<AtomicBool>,
    handle: Option<thread::JoinHandle<()>>,
}

impl MultiSpinner {
    /// Handle for anything that prints below the header — cargo's output, SteamCMD's progress, one line per
    /// packed addon. It is the only way to write there, so the header can never lose track of the count.
    pub fn sub_lines(&self) -> SubLines {
        SubLines { count: Arc::clone(&self.lines_below) }
    }

    pub fn start(label: impl Into<String>) -> Self {
        let label: String = label.into();
        let stop = Arc::new(AtomicBool::new(false));
        let lines_below: LineCount = Arc::new(Mutex::new(0));

        let stop_clone = Arc::clone(&stop);
        let lines_clone = Arc::clone(&lines_below);
        let label_clone = label.clone();

        // Print initial header line
        let yellow = color::YELLOW;
        println!("  {} {}", FRAMES[0].to_string().truecolor(yellow.0, yellow.1, yellow.2), label.bold());
        let _ = io::stdout().flush();

        let handle = thread::spawn(move || {
            let mut idx = 1usize;
            while !stop_clone.load(Ordering::Relaxed) {
                thread::sleep(Duration::from_millis(80));
                if stop_clone.load(Ordering::Relaxed) {
                    break;
                }

                // Held across the rewrite, not just the read: nothing may print below the header while the
                // cursor is parked on it.
                let n = lines(&lines_clone);
                // Cursor is currently at line (header + n + 1).
                // Move up (n+1) to reach the header line, rewrite it,
                // then move back down (n+1) and return to column 0.
                let up = *n + 1;
                let frame = FRAMES[idx % FRAMES.len()];
                let yellow = color::YELLOW;

                print!(
                    "\x1b[{up}A\r  {frame} {label}\x1b[{up}B\r",
                    frame = frame.to_string().truecolor(yellow.0, yellow.1, yellow.2),
                    label = label_clone.bold(),
                );
                let _ = io::stdout().flush();
                idx = idx.wrapping_add(1);
            }
        });

        MultiSpinner { label, lines_below, stop, handle: Some(handle) }
    }

    /// Print a label before a sub-step begins (e.g. before cargo output).
    pub fn sub_start(&mut self, label: &str, is_last: bool) {
        let dim = color::DIM;
        let mut count = lines(&self.lines_below);
        println!(
            "  {}{}",
            tree_branch(is_last),
            label.truecolor(dim.0, dim.1, dim.2).italic(),
        );
        *count += 1;
    }

    /// Print a sub-step success line.
    pub fn sub_done(&mut self, label: &str, is_last: bool) {
        let green = color::GREEN;
        let dots = dot_leader(label, STEP_WIDTH - 6);
        let mut count = lines(&self.lines_below);
        println!(
            "  {}{}{} {}",
            tree_branch(is_last),
            label.bold(),
            dots,
            "done".truecolor(green.0, green.1, green.2),
        );
        *count += 1;
    }

    /// Print a sub-step failure line.
    pub fn sub_fail(&mut self, label: &str, is_last: bool) {
        let red = color::RED;
        let dots = dot_leader(label, STEP_WIDTH - 6);
        let mut count = lines(&self.lines_below);
        println!(
            "  {}{}{} {}",
            tree_branch(is_last),
            label.bold(),
            dots,
            "failed".truecolor(red.0, red.1, red.2),
        );
        *count += 1;
    }

    pub fn done(mut self) {
        self.stop_thread();
        self.print_result(true);
    }

    fn stop_thread(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            let _ = h.join();
        }

        // The animation thread left the last braille frame in the header.
        // Replace it with a static · so it doesn't look stuck.
        let n = lines(&self.lines_below);
        let up = *n + 1;
        let dim = color::DIM;
        print!(
            "\x1b[{up}A\r  {dot} {label}\x1b[{up}B\r",
            dot = '·'.to_string().truecolor(dim.0, dim.1, dim.2),
            label = self.label.bold(),
        );
        let _ = io::stdout().flush();
    }

    fn print_result(&self, success: bool) {
        let green = color::GREEN;
        let red = color::RED;
        let dots = dot_leader(&self.label, STEP_WIDTH);
        let (icon, result_color, status) = if success {
            ('✓', green, "done")
        } else {
            ('✗', red, "failed")
        };
        println!(
            "  {} {}{} {}",
            icon.to_string().truecolor(result_color.0, result_color.1, result_color.2).bold(),
            self.label.bold(),
            dots,
            status.truecolor(result_color.0, result_color.1, result_color.2),
        );
    }
}

impl Drop for MultiSpinner {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            let _ = h.join();
        }
    }
}
