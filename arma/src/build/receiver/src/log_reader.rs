use crate::{BuildResult, LogLine};
use lazy_static::lazy_static;
use random_color::RandomColor;
use regex::Regex;
use std::{
    collections::HashSet,
    fs::File,
    io::{BufRead, BufReader},
    path::PathBuf,
    sync::atomic::{AtomicBool, Ordering},
    time::{Duration, Instant},
};

#[derive(Debug)]
pub struct FileReader {
    pub current_line: usize,
    pub file_path: PathBuf,
    pub file_name: String,
    pub color: [u8; 3],
    pub reader: Option<BufReader<File>>,
}

impl FileReader {
    pub fn new(file_path: PathBuf) -> Self {
        FileReader {
            current_line: 1,
            file_name: file_path.file_name().unwrap().to_string_lossy().to_string(),
            file_path,
            color: RandomColor::new().to_rgb_array(),
            reader: None,
        }
    }

    pub fn read_lines(&mut self) -> Vec<LogLine> {
        let mut log_lines = Vec::new();
        if !self.ready_for_reading() {
            return log_lines;
        }

        let reader = match &mut self.reader {
            Some(r) => r,
            None => return log_lines,
        };

        for _ in 0..25 {
            let mut line = String::new();
            if let Ok(bytes) = reader.read_line(&mut line) {
                if bytes == 0 || line.is_empty() {
                    continue;
                }

                log_lines.push(LogLine {
                    color: self.color,
                    filename: self.file_name.to_owned(),
                    content: line,
                    line_number: self.current_line,
                });

                self.current_line += 1;
            }
        }

        log_lines
    }

    fn ready_for_reading(&mut self) -> bool {
        if self.reader.is_some() {
            return true;
        }

        if !self.file_path.exists() {
            return false;
        }

        self.reader = Some(BufReader::new(File::open(&self.file_path).unwrap()));
        true
    }
}

pub struct LogReader {
    server_path: PathBuf,
    server_args: String,
    files: Vec<FileReader>,
    read: AtomicBool,
    tracked_files: HashSet<PathBuf>, // Keep track of files we're already reading
    last_scan: Instant,
}

impl LogReader {
    pub fn new(server_path: PathBuf, server_args: String) -> Self {
        Self {
            server_path,
            server_args,
            files: Vec::new(),
            read: AtomicBool::new(false),
            tracked_files: HashSet::new(),
            last_scan: Instant::now(),
        }
    }

    // Define your log patterns here - add new ones as needed!
    fn get_log_patterns(&self) -> Vec<String> {
        let mut patterns = vec![
            // ESM logs
            self.server_path
                .join("@esm")
                .join("log")
                .join("esm.log")
                .to_string_lossy()
                .to_string(),
            // ExtDB logs (your new one!)
            self.server_path
                .join("@exileserver")
                .join("logs")
                .join("*")
                .join("*")
                .join("*")
                .join("*.log")
                .to_string_lossy()
                .to_string(),
        ];

        // RPT logs (need special handling for profile parsing)
        if let Some(rpt_pattern) = self.get_rpt_pattern() {
            patterns.push(rpt_pattern);
        }

        patterns
    }

    fn get_rpt_pattern(&self) -> Option<String> {
        lazy_static! {
            static ref PROFILES_REGEX: Regex =
                Regex::new(r#"-profiles=(\w+)"#).unwrap();
        }

        let captures = PROFILES_REGEX.captures(&self.server_args)?;
        let profile_name = captures.get(1)?.as_str();

        Some(
            self.server_path
                .join(profile_name)
                .join("*.rpt")
                .to_string_lossy()
                .to_string(),
        )
    }

    fn scan_for_new_files(&mut self) {
        if self.last_scan.elapsed() < Duration::from_millis(500) {
            return;
        }

        self.last_scan = Instant::now();

        for pattern in self.get_log_patterns() {
            if let Ok(paths) = glob::glob(&pattern) {
                for path_result in paths {
                    if let Ok(path) = path_result {
                        // Only add files we haven't seen before
                        if !self.tracked_files.contains(&path) && path.exists() {
                            self.files.push(FileReader::new(path.clone()));
                            self.tracked_files.insert(path);
                        }
                    }
                }
            }
        }
    }

    pub fn read_lines(&mut self) -> Vec<LogLine> {
        if !self.read.load(Ordering::SeqCst) {
            return vec![];
        }

        // Check for new log files
        self.scan_for_new_files();

        // Read from all active files
        self.files.iter_mut().flat_map(|f| f.read_lines()).collect()
    }

    pub fn stop_reads(&self) {
        self.read.store(false, Ordering::SeqCst);
    }

    pub fn reset(&mut self) -> BuildResult {
        self.stop_reads();
        self.files.clear();
        self.tracked_files.clear();
        self.last_scan = Instant::now();

        // Start reading - files will be discovered dynamically
        self.read.store(true, Ordering::SeqCst);

        Ok(())
    }
}
