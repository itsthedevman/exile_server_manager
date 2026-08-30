use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    time::{Duration, SystemTime},
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

    /// Read the previous run's snapshot and take a fresh one, without committing anything.
    ///
    /// Taking a snapshot is not the same as having acted on it, so nothing is written here. Every invocation of
    /// this binary builds a watcher, and only some of them go on to build: one that stages a test position or
    /// merely starts a server would otherwise record every pending edit as seen, and the next real build would
    /// find nothing to do and deploy the previous artifact while reporting success. [`FileWatcher::record`] is
    /// what says a build happened.
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

        Ok(self)
    }

    /// Commit the snapshot taken at load time, marking everything in it as built.
    ///
    /// The load-time snapshot is written rather than a fresh scan on purpose. A source file edited while the
    /// build was running is not in the artifact that build produced, and re-scanning here would record it as
    /// though it were. Keeping the older timestamps leaves it looking modified, so the next run rebuilds it.
    pub fn record(&self) -> Result<(), String> {
        let content = serde_json::to_string(&self.latest_file_cache).map_err(|e| e.to_string())?;

        std::fs::write(&self.cache_path, content).map_err(|e| format!("{e}"))
    }

    pub fn was_modified(&self, path: &Path) -> bool {
        let path = match path.strip_prefix(&*self.root_path.to_string_lossy()) {
            Ok(p) => PathBuf::from(p),
            Err(_) => return true,
        };

        if !self.watched_path(&path) {
            return false;
        }

        // Makes the default time to one second ago so the check will work
        let Some(previously_modified_at) = SystemTime::now().checked_sub(Duration::from_secs(1)) else {
            return true;
        };

        let previously_modified_at = match self.previous_file_cache.get(&path) {
            Some(t) => t,
            None => &previously_modified_at,
        };

        let current_time = SystemTime::now();
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
