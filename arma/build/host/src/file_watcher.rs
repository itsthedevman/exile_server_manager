use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    time::SystemTime,
};

use glob::glob;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileWatcher {
    previous_file_cache: HashMap<PathBuf, SystemTime>,
    latest_file_cache: HashMap<PathBuf, SystemTime>,
    watching_paths: Vec<PathBuf>,
    ignored_paths: Vec<PathBuf>,
    root_path: PathBuf,
    cache_path: PathBuf,
}

impl FileWatcher {
    pub fn new(root_path: &PathBuf, temp_path: &Path) -> Self {
        Self {
            previous_file_cache: HashMap::new(),
            latest_file_cache: HashMap::new(),
            watching_paths: vec![],
            ignored_paths: vec![],
            root_path: root_path.to_owned(),
            cache_path: temp_path.join(".esm-watcher.json"),
        }
    }

    pub fn watch(mut self, path: &Path) -> Self {
        let path = match path.strip_prefix(&*self.root_path.to_string_lossy()) {
            Ok(p) => PathBuf::from(p),
            Err(_) => return self,
        };

        if !self.watching_paths.contains(&path) {
            self.watching_paths.push(path);
        }

        self
    }

    pub fn ignore(mut self, path: &Path) -> Self {
        let path = match path.strip_prefix(&*self.root_path.to_string_lossy()) {
            Ok(p) => PathBuf::from(p),
            Err(_) => return self,
        };

        if !self.ignored_paths.contains(&path) {
            self.ignored_paths.push(path);
        }

        self
    }

    pub fn load(mut self) -> Result<Self, String> {
        if let Ok(c) = std::fs::read(&self.cache_path) {
            if let Ok(cache) = serde_json::from_slice(&c) {
                self.previous_file_cache = cache;
            }
        };

        let Ok(file_paths) = glob(&format!("{}/**/*", self.root_path.to_string_lossy())) else {
            return Err("Failed to get file paths for file watcher".into());
        };

        for entry in file_paths {
            let Ok(path) = entry else {
                continue;
            };

            let path = match path.strip_prefix(&*self.root_path.to_string_lossy()) {
                Ok(p) => PathBuf::from(p),
                Err(_) => continue,
            };

            if !self.watched_path(&path) {
                continue;
            }

            let Ok(metadata) = std::fs::metadata(&path) else {
                continue;
            };

            self.latest_file_cache
                .insert(path, metadata.modified().unwrap());
        }

        if let Ok(content) = serde_json::to_string(&self.latest_file_cache) {
            if let Err(e) = std::fs::write(&self.cache_path, content) {
                return Err(format!("{e}"));
            }
        }

        Ok(self)
    }

    pub fn was_modified(&self, path: &Path) -> bool {
        let path = match path.strip_prefix(&*self.root_path.to_string_lossy()) {
            Ok(p) => PathBuf::from(p),
            Err(_) => return true,
        };

        let current_time = SystemTime::now();
        let previously_modified_at = match self.previous_file_cache.get(&path) {
            Some(t) => t,
            None => &current_time,
        };

        let current_modified_at = match self.latest_file_cache.get(&path) {
            Some(t) => t,
            None => &current_time,
        };

        previously_modified_at < current_modified_at
    }

    fn watched_path(&self, path: &Path) -> bool {
        let is_watched = self
            .watching_paths
            .iter()
            .any(|p| path.starts_with(p) || path == p);

        let is_ignored = self
            .ignored_paths
            .iter()
            .any(|p| path.starts_with(p) || path == p);

        is_watched && !is_ignored
    }
}
