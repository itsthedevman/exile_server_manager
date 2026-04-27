use std::{
    io::{self, Write},
    sync::{
        atomic::{AtomicBool, AtomicUsize, Ordering},
        Arc,
    },
    thread,
    time::Duration,
};

use colored::Colorize;

use crate::display::{color, dot_leader, tree_branch};

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

/// Spinner for steps that stream sub-step output below a header line.
///
/// The header line animates in a background thread by using ANSI cursor-up to
/// rewrite it without disturbing the sub-step lines that have been printed below.
pub struct MultiSpinner {
    label: String,
    /// Number of lines printed below the header (sub-steps).
    lines_below: Arc<AtomicUsize>,
    stop: Arc<AtomicBool>,
    handle: Option<thread::JoinHandle<()>>,
}

impl MultiSpinner {
    /// Returns a clone of the internal line counter.
    /// Pass it to any code that prints below the header (e.g. cargo output)
    /// so the animation thread knows exactly how far up to jump.
    pub fn line_counter(&self) -> Arc<AtomicUsize> {
        Arc::clone(&self.lines_below)
    }

    pub fn start(label: impl Into<String>) -> Self {
        let label: String = label.into();
        let stop = Arc::new(AtomicBool::new(false));
        let lines_below = Arc::new(AtomicUsize::new(0));

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

                let n = lines_clone.load(Ordering::Relaxed);
                // Cursor is currently at line (header + n + 1).
                // Move up (n+1) to reach the header line, rewrite it,
                // then move back down (n+1) and return to column 0.
                let up = n + 1;
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
        println!(
            "  {}{}",
            tree_branch(is_last),
            label.truecolor(dim.0, dim.1, dim.2).italic(),
        );
        self.lines_below.fetch_add(1, Ordering::Relaxed);
    }

    /// Print a sub-step success line.
    pub fn sub_done(&mut self, label: &str, is_last: bool) {
        let green = color::GREEN;
        let dots = dot_leader(label, STEP_WIDTH - 6);
        println!(
            "  {}{}{} {}",
            tree_branch(is_last),
            label.bold(),
            dots,
            "done".truecolor(green.0, green.1, green.2),
        );
        self.lines_below.fetch_add(1, Ordering::Relaxed);
    }

    /// Print a sub-step failure line.
    pub fn sub_fail(&mut self, label: &str, is_last: bool) {
        let red = color::RED;
        let dots = dot_leader(label, STEP_WIDTH - 6);
        println!(
            "  {}{}{} {}",
            tree_branch(is_last),
            label.bold(),
            dots,
            "failed".truecolor(red.0, red.1, red.2),
        );
        self.lines_below.fetch_add(1, Ordering::Relaxed);
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
        let n = self.lines_below.load(Ordering::Relaxed);
        let up = n + 1;
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
