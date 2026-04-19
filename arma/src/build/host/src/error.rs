use compiler::CompilerError;

#[derive(Debug, thiserror::Error)]
pub enum BuildError {
    #[error("{0}")]
    General(String),

    #[error("Docker: {0}")]
    Docker(String),

    #[error("Config: {0}")]
    Config(String),

    #[error("{0}")]
    Io(#[from] std::io::Error),

    #[error("{0}")]
    Compiler(#[from] CompilerError),

    #[error("{0}")]
    Yaml(#[from] serde_yaml::Error),

    #[error("{0}")]
    Redis(redis::RedisError),

    #[error("{0}")]
    Json(#[from] serde_json::Error),
}

pub type BuildResult = Result<(), BuildError>;

impl From<String> for BuildError {
    fn from(s: String) -> Self {
        Self::General(s)
    }
}

impl From<&str> for BuildError {
    fn from(s: &str) -> Self {
        Self::General(s.to_owned())
    }
}
