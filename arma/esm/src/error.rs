pub type ESMResult = Result<(), ESMError>;

#[derive(Debug)]
pub struct ESMError(String);

impl std::fmt::Display for ESMError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}
impl std::error::Error for ESMError {
    fn cause(&self) -> Option<&dyn std::error::Error> {
        Some(self)
    }
}

impl From<std::io::Error> for ESMError {
    fn from(e: std::io::Error) -> Self {
        Self(e.to_string())
    }
}

impl From<String> for ESMError {
    fn from(e: String) -> Self {
        Self(e)
    }
}

impl From<&str> for ESMError {
    fn from(e: &str) -> Self {
        Self(e.to_string())
    }
}

impl From<std::num::ParseIntError> for ESMError {
    fn from(e: std::num::ParseIntError) -> Self {
        Self(e.to_string())
    }
}

impl From<std::num::ParseFloatError> for ESMError {
    fn from(e: std::num::ParseFloatError) -> Self {
        Self(e.to_string())
    }
}
