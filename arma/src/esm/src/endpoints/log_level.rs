use super::*;

pub fn log_level() -> String {
    let log_level = CONFIG.log_level.to_lowercase();
    trace!("[log_level] - {log_level}");

    log_level
}
