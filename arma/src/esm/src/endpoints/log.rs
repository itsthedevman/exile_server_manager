use super::*;

pub fn log(log_level: String, caller: String, content: String) {
    let timer = std::time::Instant::now();
    trace!(
        "[log] log_level: {:?} - caller: {:?} - content size: {:?} bytes",
        log_level,
        caller,
        content.len()
    );

    let message = format!("{caller} | {content}");

    match log_level.to_ascii_lowercase().as_str() {
        "trace" => trace!("{message}"),
        "debug" => debug!("{message}"),
        "info" => info!("{message}"),
        "warn" => warn!("{message}"),
        "error" => error!("{message}"),
        t => error!(
            "[#log] Invalid log level provided. Received {}, expected debug, info, warn, error",
            t
        ),
    }

    trace!("[log] ⏲ Took {:.2?}", timer.elapsed());
}
