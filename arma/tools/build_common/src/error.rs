use vfs::VfsError;

#[derive(Debug)]
pub enum BuildError {
    Generic(String),
}

impl std::fmt::Display for BuildError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match *self {
            Self::Generic(ref e) => write!(f, "{}", e),
        }
    }
}

impl std::error::Error for BuildError {
    fn cause(&self) -> Option<&dyn std::error::Error> {
        Some(&*self)
    }
}

impl From<VfsError> for BuildError {
    fn from(e: VfsError) -> Self {
        Self::Generic(e.to_string())
    }
}

impl From<serde_yaml::Error> for BuildError {
    fn from(e: serde_yaml::Error) -> Self {
        Self::Generic(e.to_string())
    }
}

impl From<std::io::Error> for BuildError {
    fn from(e: std::io::Error) -> Self {
        Self::Generic(e.to_string())
    }
}
