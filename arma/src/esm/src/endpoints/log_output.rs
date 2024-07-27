use super::*;

pub fn log_output() -> String {
    let log_output = CONFIG.log_output.to_lowercase();
    trace!("[log_output] - {log_output}");

    log_output
}
