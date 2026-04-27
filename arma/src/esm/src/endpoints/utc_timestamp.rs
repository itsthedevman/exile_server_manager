use super::*;

pub fn utc_timestamp() -> String {
    let timestamp = Utc::now().to_rfc3339();
    trace!("[utc_timestamp] - {timestamp}");

    timestamp
}
