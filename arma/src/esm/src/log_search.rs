use chrono::{DateTime, Duration, Utc};
use regex::{Regex, RegexBuilder};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tokio::fs::{self, File};
use tokio::io::{AsyncBufReadExt, BufReader};

pub async fn search_files(search: &str) -> Result<Vec<MatchResult>, String> {
    let pattern = RegexBuilder::new(search)
        .case_insensitive(true)
        .build()
        .map_err(|e| format!("Invalid regex pattern: {}", e))?;

    let server_mod_name = crate::CONFIG.server_mod_name.clone();
    let exile_log_search_days = crate::CONFIG.exile_logs_search_days as u32;

    let log_finder = LogFinder::new(&server_mod_name, exile_log_search_days);

    let paths: Vec<PathBuf> = log_finder
        .get_exile_log_paths()
        .await?
        .into_iter()
        .chain(log_finder.get_additional_log_paths().await)
        .collect();

    let mut results: Vec<MatchResult> = vec![];
    for path in paths {
        let paths = search_file(path, &pattern).await?;
        results.extend(paths);
    }

    Ok(results)
}

pub struct LogFinder<'a> {
    server_mod_name: &'a str,
    exile_log_search_days: u32,
}

impl<'a> LogFinder<'a> {
    pub fn new(server_mod_name: &'a str, exile_log_search_days: u32) -> Self {
        Self {
            server_mod_name,
            exile_log_search_days,
        }
    }

    pub fn normalize_path(path: PathBuf) -> PathBuf {
        if path.is_absolute() {
            path.to_path_buf()
        } else {
            // Remove any leading "./" or "\" if present
            let clean_path = path
                .strip_prefix("./")
                .or_else(|_| path.strip_prefix(".\\"))
                .unwrap_or(&path);

            Path::new(".").join(clean_path)
        }
    }

    pub async fn get_exile_log_paths(&self) -> Result<Vec<PathBuf>, String> {
        let using_extdb3 = crate::DATABASE.extdb_version == 3;
        let base_path = Path::new(self.server_mod_name);

        let base_path = if using_extdb3 {
            base_path.join("logs")
        } else {
            base_path.join("extDB").join("logs")
        };

        let mut paths = Vec::new();
        let now = Utc::now();

        for days_back in 0..self.exile_log_search_days {
            let date = now - Duration::days(days_back as i64);

            if let Some(path) = self.construct_extdb_date_path(&base_path, date) {
                paths.push(path);
            }
        }

        let mut log_paths = vec![];
        for path in paths {
            log_paths.extend(
                self.find_logs_in_directory(&path)
                    .await
                    .map_err(|e| e.to_string())?,
            );
        }

        Ok(log_paths)
    }

    pub async fn get_additional_log_paths(&self) -> Vec<PathBuf> {
        crate::CONFIG
            .additional_logs
            .iter()
            .map(|path| Path::new(path).to_path_buf())
            .map(|path| Self::normalize_path(path))
            .collect()
    }

    async fn find_logs_in_directory(
        &self,
        path: &Path,
    ) -> Result<Vec<PathBuf>, std::io::Error> {
        let mut logs = Vec::new();

        // Return empty vec if directory doesn't exist
        if !fs::try_exists(path).await? {
            return Ok(logs);
        }

        let mut entries = fs::read_dir(path).await?;

        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();

            if path.is_file() {
                logs.push(path);
            }
        }

        Ok(logs)
    }

    fn construct_extdb_date_path(
        &self,
        base_path: &Path,
        date: DateTime<Utc>,
    ) -> Option<PathBuf> {
        let path = base_path
            .join(date.format("%Y").to_string()) // Year
            .join(date.format("%-m").to_string()) // Month without leading zero
            .join(date.format("%-d").to_string()); // Day without leading zero

        Some(path)
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MatchResult {
    file_name: String,
    line_number: usize,
    content: String,
}

async fn search_file(
    path: PathBuf,
    pattern: &Regex,
) -> Result<Vec<MatchResult>, String> {
    // Check if file exists
    if !tokio::fs::try_exists(&path)
        .await
        .map_err(|e| format!("Error checking file existence: {}", e))?
    {
        return Err(format!("File does not exist: {}", path.display()));
    }

    let file = File::open(&path)
        .await
        .map_err(|e| format!("Failed to open file: {}", e))?;

    let mut reader = BufReader::new(file);
    let mut line = Vec::new();
    let mut matches = Vec::new();
    let mut line_number = 1;

    loop {
        line.clear();

        let bytes_read = reader
            .read_until(b'\n', &mut line)
            .await
            .map_err(|e| format!("Error reading line {}: {}", line_number, e))?;

        if bytes_read == 0 {
            break;
        }

        let line_text = String::from_utf8_lossy(&line).into_owned();

        if pattern.is_match(&line_text) {
            matches.push(MatchResult {
                file_name: path.display().to_string(),
                line_number,
                content: line_text.trim().to_string(),
            });
        }

        line_number += 1;
    }

    Ok(matches)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;
    use tokio::fs::write;

    #[tokio::test]
    async fn test_file_not_found() {
        let path = PathBuf::from("nonexistent.txt");
        let pattern = RegexBuilder::new(r"test")
            .case_insensitive(true)
            .build()
            .unwrap();

        let result = search_file(path, &pattern).await;

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("does not exist"));
    }

    #[tokio::test]
    async fn test_matching_lines() {
        let file = NamedTempFile::new().unwrap();
        write(file.path(), "test1\nno match\ntest2\n")
            .await
            .unwrap();

        let pattern = RegexBuilder::new(r"test\d")
            .case_insensitive(true)
            .build()
            .unwrap();

        let results = search_file(file.path().to_path_buf(), &pattern)
            .await
            .unwrap();

        assert_eq!(results.len(), 2);
        assert_eq!(results[0].line_number, 1);
        assert_eq!(results[0].content, "test1");
        assert_eq!(results[1].line_number, 3);
        assert_eq!(results[1].content, "test2");
    }
}
