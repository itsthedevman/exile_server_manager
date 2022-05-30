use super::{BuildOS, BuildEnv, LogLevel};

#[derive(Debug)]
pub enum BuildArch {
    X32,
    X64,
}

pub struct Builder {
    pub target: BuildOS,
    pub arch: BuildArch,
    pub env: BuildEnv,
    pub log_level: LogLevel,
    pub git_directory: String,
    pub build_directory: String,
}

impl Builder {
    pub fn new(build_x32: bool, target: BuildOS,  log_level: LogLevel, env: BuildEnv) -> Self {
        let git_directory = match std::env::current_dir() {
            Ok(d) => d.to_string_lossy().to_string(),
            Err(e) => panic!("{e}")
        };

        let build_directory = format!("{}/target/@esm", git_directory);

        Builder {
            target,
            arch: if build_x32 { BuildArch::X32 } else { BuildArch::X64 },
            env,
            log_level,
            git_directory,
            build_directory,
        }
    }
}
