#[derive(Debug, PartialEq, Eq)]
pub enum CompilerError {
    Generic(String),
}

impl std::fmt::Display for CompilerError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match *self {
            Self::Generic(ref e) => write!(f, "{}", e),
        }
    }
}

impl std::error::Error for CompilerError {
    fn cause(&self) -> Option<&dyn std::error::Error> {
        Some(self)
    }
}

impl From<std::io::Error> for CompilerError {
    fn from(e: std::io::Error) -> Self {
        Self::Generic(e.to_string())
    }
}

impl From<String> for CompilerError {
    fn from(e: String) -> Self {
        Self::Generic(e)
    }
}

impl From<&str> for CompilerError {
    fn from(e: &str) -> Self {
        e.to_string().into()
    }
}
