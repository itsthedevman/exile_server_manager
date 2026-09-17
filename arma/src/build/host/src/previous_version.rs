use std::path::{Path, PathBuf};

use crate::error::BuildError;

/// Where released builds of `@esm` are kept for testing against, relative to the git root.
const PREVIOUS_VERSIONS_DIR: [&str; 2] = ["tools", "previous_versions"];

/// Find the stored build of `@esm` for a release, e.g. `2.0.4` in `tools/previous_versions/@esm-204`.
///
/// Each directory is a whole `@esm` as it shipped, test addon included, so a deploy can hand it over in place of the
/// staging tree without anything from the current build leaking in alongside it.
pub fn resolve(git_path: &Path, version: &str) -> Result<PathBuf, BuildError> {
    let root = git_path.join(PREVIOUS_VERSIONS_DIR[0]).join(PREVIOUS_VERSIONS_DIR[1]);
    let path = root.join(directory_name(version)?);

    if path.is_dir() {
        return Ok(path);
    }

    let available = available_directories(&root);
    let available = if available.is_empty() { "none".to_string() } else { available.join(", ") };

    Err(BuildError::General(format!(
        "No stored build of @esm {version} at {}\n  Available: {available}",
        path.display()
    )))
}

/// `2.0.4` becomes `@esm-204`. Releases are always three plain numbers, so anything else is a typo rather than a
/// version worth guessing at.
fn directory_name(version: &str) -> Result<String, BuildError> {
    let parts: Vec<&str> = version.split('.').collect();

    let is_release = parts.len() == 3
        && parts.iter().all(|part| !part.is_empty() && part.chars().all(|character| character.is_ascii_digit()));

    if !is_release {
        return Err(BuildError::General(format!(
            "Invalid @esm version '{version}'. Expected a release number like 2.0.4"
        )));
    }

    Ok(format!("@esm-{}", parts.concat()))
}

fn available_directories(root: &Path) -> Vec<String> {
    let Ok(entries) = std::fs::read_dir(root) else {
        return Vec::new();
    };

    let mut names: Vec<String> = entries
        .filter_map(Result::ok)
        .filter(|entry| entry.path().is_dir())
        .map(|entry| entry.file_name().to_string_lossy().into_owned())
        .filter(|name| name.starts_with("@esm-"))
        .collect();

    names.sort();
    names
}

#[cfg(test)]
mod tests {
    use super::{directory_name, resolve};

    #[test]
    fn a_release_drops_its_dots() {
        assert_eq!(directory_name("2.0.4").unwrap(), "@esm-204");
        assert_eq!(directory_name("2.10.0").unwrap(), "@esm-2100");
    }

    #[test]
    fn anything_but_three_plain_numbers_is_refused() {
        for version in ["2.0", "2.0.4.1", "v2.0.4", "2.0.4+754da3bb", "2..4", ""] {
            assert!(directory_name(version).is_err(), "{version} should have been refused");
        }
    }

    #[test]
    fn a_missing_version_names_the_ones_that_exist() {
        let root = std::env::temp_dir().join(format!("esm_previous_version_{}", std::process::id()));
        let versions = root.join("tools").join("previous_versions");

        std::fs::create_dir_all(versions.join("@esm-204")).unwrap();
        std::fs::create_dir_all(versions.join("@esm-203")).unwrap();

        let found = resolve(&root, "2.0.4");
        let missing = resolve(&root, "2.0.9").unwrap_err().to_string();

        std::fs::remove_dir_all(&root).unwrap();

        assert_eq!(found.unwrap(), versions.join("@esm-204"));
        assert!(missing.contains("@esm-203, @esm-204"), "{missing}");
    }
}
