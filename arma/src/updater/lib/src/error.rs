//! Error types for the updater library.

use thiserror::Error;

/// All errors that can occur during update operations.
#[derive(Error, Debug)]
pub enum UpdaterError {
    /// An HTTP request failed or returned a non-success status.
    #[error("HTTP error: {0}")]
    Http(String),

    /// The manifest signature did not verify against the baked-in public key.
    #[error("invalid manifest signature")]
    BadSignature,

    /// The downloaded file's SHA-256 hash did not match the manifest entry.
    #[error("SHA256 mismatch: expected {expected}, got {actual}")]
    ChecksumMismatch { expected: String, actual: String },

    /// A semver parse or comparison failed.
    #[error("semver error: {0}")]
    Semver(#[from] semver::Error),

    /// An I/O operation failed.
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    /// A file could not be replaced because another process is holding it open.
    ///
    /// Its own variant rather than a plain IO error because it is the one failure an operator can act on, and
    /// the raw message ("The process cannot access the file because it is being used by another process") names
    /// neither the file nor the process nor what to do about it.
    #[error(
        "{path} is in use by another process, so it could not be replaced.\n\
         Stop the Arma server and run this again. Windows will not rename or delete a file while a running \
         process holds it open, and a server that has loaded the extension holds it for as long as it runs.\n\
         Nothing was changed."
    )]
    FileInUse { path: String },

    /// Extracting the tar.gz archive failed.
    #[error("archive error: {0}")]
    Extract(String),

    /// The manifest entry did not include a sha256 field.
    #[error("manifest missing sha256")]
    NoChecksum,

    /// The manifest JSON could not be parsed.
    #[error("manifest parse error: {0}")]
    Parse(String),

    /// The operation deadline elapsed before completion.
    #[error("deadline exceeded")]
    Deadline,

    /// A component dependency version requirement was not met.
    #[error(
        "dependency unmet: {component} requires {dependency} >= {required}"
    )]
    DependencyUnmet {
        component: String,
        dependency: String,
        required: String,
    },

    /// The updater is disabled in configuration.
    #[error("updater disabled")]
    Disabled,

    /// An unexpected internal error occurred.
    #[error("internal error")]
    Internal,
}
