use super::{BuildOS, BuildENV, LogLevel};

enum BuildArch {
    X32,
    X64,
}

pub struct Builder {
    pub os: BuildOS,
    pub arch: BuildArch,
    pub env: BuildENV,
    pub log_level: LogLevel,
}

impl Builder {
    pub fn new(args: ()) -> Self {
        Builder {
            os: args.os,
            arch: if args.build_x32 { BuildArch::X32 } else { BuildArch::X64 },
            env: args.env,
            log_level: args.target,
        }
    }
}
