//! File logging shared by the extension and the CLI.
//!
//! Both write to the path in `config.updater_log_path` so one file tells the whole story of a server's updates,
//! whether a component arrived during boot or because an operator asked for it. Splitting them across two
//! destinations means answering "what happened to this server" requires knowing which half to ask first.

use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;

const LOG_PATTERN: &str = "[{d(%Y-%m-%d %H:%M:%S%.3f)(utc)}Z {h({l})} {M}:{L}] {m}{n}";

/// Send `log` output to `log_path` at info level.
///
/// Errors are reported and swallowed rather than returned. Logging is how a run explains itself, not part of what
/// it does, and refusing to update a server because a log file could not be opened trades a real problem for a
/// cosmetic one. The caller gets a line on stdout either way, so a missing log is visible rather than silent.
///
/// Call this after any working-directory change: `log_path` defaults to a location under the server root, so
/// initialising first would open a log in whichever directory the process happened to start in.
pub fn initialize(log_path: &str) {
    let logfile = match FileAppender::builder()
        .encoder(Box::new(PatternEncoder::new(LOG_PATTERN)))
        .build(log_path)
    {
        Ok(appender) => appender,
        Err(e) => {
            println!("[ESM Updater] failed to create log file at {log_path}: {e}");
            return;
        }
    };

    let config = match LogConfig::builder()
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(Root::builder().appender("logfile").build(log::LevelFilter::Info))
    {
        Ok(config) => config,
        Err(e) => {
            println!("[ESM Updater] failed to build log config: {e}");
            return;
        }
    };

    if let Err(e) = log4rs::init_config(config) {
        println!("[ESM Updater] failed to init logger: {e}");
    }
}
