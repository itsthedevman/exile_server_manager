use std::io::BufReader;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::{fs::File, io::BufRead};

use crate::LogLine;
use common::BuildResult;
use lazy_static::lazy_static;
use random_color::RandomColor;
use regex::Regex;

use crate::Args;

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
    pub files: Vec<FileReader>,
    pub read: AtomicBool,
    server_path: PathBuf,
    server_args: String,
}

impl LogReader {
    pub fn new(args: &Args) -> Self {
        LogReader {
            files: Vec::new(),
            read: AtomicBool::new(true),
            server_path: PathBuf::from(&args.a3_server_path),
            server_args: args.a3_server_args.to_owned(),
        }
    }

    pub fn read_lines(&mut self) -> Vec<LogLine> {
        for _ in 0..5 {
            if !self.read.load(Ordering::SeqCst) {
                return vec![];
            }

            let new_lines: Vec<LogLine> =
                self.files.iter_mut().flat_map(|f| f.read_lines()).collect();

            if new_lines.is_empty() {
                continue;
            }

            return new_lines;
        }

        vec![]
    }

    pub fn stop_reads(&self) {
        self.read.store(false, Ordering::SeqCst);
    }

    pub fn reset(&mut self) -> BuildResult {
        self.stop_reads();
        self.files.clear();

        // @esm/log/esm.log
        self.files.push(FileReader::new(
            self.server_path.join("@esm").join("log").join("esm.log"),
        ));

        // Arma 3 RPT
        loop {
            let path = rtp_path(&self.server_path, &self.server_args);
            if path.is_none() {
                continue;
            }

            self.files.push(FileReader::new(path.unwrap()));
            break;
        }

        self.read.store(true, Ordering::SeqCst);

        Ok(())
    }
}

fn rtp_path(server_path: &Path, server_args: &str) -> Option<PathBuf> {
    lazy_static! {
        static ref PROFILES_REGEX: Regex = Regex::new(r#"-profiles=(\w+)"#).unwrap();
        static ref RPT_REGEX: Regex = Regex::new(r#".+\.rpt"#).unwrap();
    };

    let captures = PROFILES_REGEX.captures(server_args).unwrap();
    let profile_name = captures.get(1)?.as_str();

    glob::glob(
        &server_path
            .join(profile_name)
            .join("*.rpt")
            .to_string_lossy()
            .to_string(),
    )
    .unwrap()
    .filter_map(|path| {
        let path = path.unwrap();
        if RPT_REGEX.is_match(path.to_str().unwrap()) {
            return Some(path);
        }

        None
    })
    .next()
}
