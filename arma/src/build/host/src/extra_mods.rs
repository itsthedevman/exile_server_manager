use std::path::Path;

/// Mods this repository ships itself, and so never something discovery has to find.
///
/// Everything else matching `tools/server/@*` is gitignored, which is what makes discovery safe: a directory
/// that turns up there was put there by hand and is meant to be loaded.
const SHIPPED_MODS: &[&str] = &["@exile", "@exileserver"];

/// Suffix marking the server-only half of a mod.
///
/// `@arcas_dev_tools` holds the half a player runs and `@arcas_dev_tools_server` the half only the server has any
/// use for, which is the split `-mod` and `-servermod` already exist to express.
const SERVER_ONLY_SUFFIX: &str = "_server";

/// Mods sitting in `tools/server` that config.yml does not name, grouped by the launch argument they belong on.
#[derive(Debug, Default, Clone)]
pub struct ExtraMods {
    /// Loaded by server and client alike, so they go on `-mod`.
    pub shared: Vec<String>,

    /// Loaded by the server alone, so they go on `-servermod` and are never advertised to a client.
    pub server_only: Vec<String>,
}

impl ExtraMods {
    pub fn is_empty(&self) -> bool {
        self.shared.is_empty() && self.server_only.is_empty()
    }

    /// Every discovered mod, which is what has to reach the target regardless of how it launches.
    pub fn all(&self) -> impl Iterator<Item = &String> {
        self.shared.iter().chain(&self.server_only)
    }
}

/// Find the mods dropped into `tools/server` alongside the two this repository ships.
///
/// Discovered rather than configured because the directory is already the only record of them: `@*` under
/// `tools/server` is gitignored, so putting a mod there is the whole of installing one, and naming it a second
/// time in config.yml would only be a way for the two to fall out of step.
///
/// A directory that cannot be read is no extras rather than an error. `check_for_exile_files` already fails the
/// build when `tools/server` is not what it should be, and it says so far better than this could.
pub fn discover(git_path: &Path) -> ExtraMods {
    let Ok(entries) = std::fs::read_dir(git_path.join("tools").join("server")) else {
        return ExtraMods::default();
    };

    let mut mods = ExtraMods::default();

    for entry in entries.filter_map(Result::ok) {
        // Through the path rather than the entry's own file type, so a mod symlinked in from the repository that
        // builds it counts as the directory it points at instead of being skipped as a link.
        if !entry.path().is_dir() {
            continue;
        }

        let name = entry.file_name().to_string_lossy().into_owned();

        if !name.starts_with('@') || SHIPPED_MODS.contains(&name.as_str()) {
            continue;
        }

        if name.ends_with(SERVER_ONLY_SUFFIX) {
            mods.server_only.push(name);
        } else {
            mods.shared.push(name);
        }
    }

    // Directory order is whatever the filesystem hands back, and a launch line that reshuffles itself between
    // runs is one more thing to rule out when a server comes up behaving differently.
    mods.shared.sort();
    mods.server_only.sort();

    mods
}

/// Fold discovered mods into the `mod=` and `servermod=` arguments, leaving every other argument alone.
///
/// `separator` is the shell's rather than Arma's: Linux escapes the semicolon and `cmd.exe` does not, which is
/// the same split config.yml already makes between `server.server_args` and `windows.server_args`.
///
/// An empty argument list stays empty. That is the shape an unconfigured Windows host launches with, and it
/// reports itself through every mod being missing; adding one mod to it would only make it look half configured.
pub fn merge_into_args(args: &[String], extras: &ExtraMods, separator: &str) -> Vec<String> {
    if args.is_empty() || extras.is_empty() {
        return args.to_vec();
    }

    let mut merged: Vec<String> = args
        .iter()
        .map(|arg| match arg.split_once('=') {
            Some(("mod", value)) if !extras.shared.is_empty() => {
                render(&extras.shared, "mod", value, separator)
            }
            Some(("servermod", value)) if !extras.server_only.is_empty() => {
                render(&extras.server_only, "servermod", value, separator)
            }
            _ => arg.to_owned(),
        })
        .collect();

    // A config naming neither argument would otherwise drop every discovered mod on the floor without saying so.
    for (key, additions) in [("mod", &extras.shared), ("servermod", &extras.server_only)] {
        let prefix = format!("{key}=");

        if additions.is_empty() || merged.iter().any(|arg| arg.starts_with(&prefix)) {
            continue;
        }

        merged.push(render(additions, key, "", separator));
    }

    merged
}

/// Rewrite one `mod=`/`servermod=` argument with `additions` appended, skipping any the value already names.
fn render(additions: &[String], key: &str, value: &str, separator: &str) -> String {
    let mut names: Vec<&str> = value
        .split(separator)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .collect();

    for addition in additions {
        if !names.contains(&addition.as_str()) {
            names.push(addition);
        }
    }

    format!("{key}={}{separator}", names.join(separator))
}

#[cfg(test)]
mod tests {
    use super::*;

    const LINUX: &str = "\\;";
    const WINDOWS: &str = ";";

    fn extras(shared: &[&str], server_only: &[&str]) -> ExtraMods {
        ExtraMods {
            shared: shared.iter().map(|name| name.to_string()).collect(),
            server_only: server_only.iter().map(|name| name.to_string()).collect(),
        }
    }

    fn args(values: &[&str]) -> Vec<String> {
        values.iter().map(|value| value.to_string()).collect()
    }

    fn tools_server(root: &Path) -> std::path::PathBuf {
        let path = root.join("tools").join("server");
        std::fs::create_dir_all(&path).expect("tools/server");
        path
    }

    /// A temporary directory of this test's own, removed when the test ends however it ends.
    struct Scratch(std::path::PathBuf);

    impl Scratch {
        fn new(name: &str) -> Self {
            let path = std::env::temp_dir().join(format!("esm-extra-mods-{name}"));
            std::fs::remove_dir_all(&path).ok();
            std::fs::create_dir_all(&path).expect("scratch");
            Scratch(path)
        }
    }

    impl Drop for Scratch {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).ok();
        }
    }

    #[test]
    fn the_server_suffix_decides_which_argument_a_mod_lands_on() {
        let scratch = Scratch::new("suffix");
        let server = tools_server(&scratch.0);

        std::fs::create_dir_all(server.join("@arcas_dev_tools")).unwrap();
        std::fs::create_dir_all(server.join("@arcas_dev_tools_server")).unwrap();

        let found = discover(&scratch.0);
        assert_eq!(found.shared, vec!["@arcas_dev_tools"]);
        assert_eq!(found.server_only, vec!["@arcas_dev_tools_server"]);
    }

    #[test]
    fn what_the_repository_ships_is_not_an_extra() {
        let scratch = Scratch::new("shipped");
        let server = tools_server(&scratch.0);

        std::fs::create_dir_all(server.join("@exile")).unwrap();
        std::fs::create_dir_all(server.join("@exileserver")).unwrap();
        std::fs::create_dir_all(server.join("mpmissions")).unwrap();
        std::fs::write(server.join("test.log"), b"").unwrap();

        assert!(discover(&scratch.0).is_empty());
    }

    #[test]
    fn a_missing_tools_directory_is_no_extras_rather_than_an_error() {
        let scratch = Scratch::new("absent");
        assert!(discover(&scratch.0).is_empty());
    }

    #[test]
    fn extras_are_appended_to_the_arguments_they_belong_on() {
        let merged = merge_into_args(
            &args(&["mod=@exile\\;", "servermod=@exileserver\\;@esm\\;", "world=empty"]),
            &extras(&["@arcas_dev_tools"], &["@arcas_dev_tools_server"]),
            LINUX,
        );

        assert_eq!(
            merged,
            args(&[
                "mod=@exile\\;@arcas_dev_tools\\;",
                "servermod=@exileserver\\;@esm\\;@arcas_dev_tools_server\\;",
                "world=empty",
            ])
        );
    }

    #[test]
    fn windows_keeps_its_bare_semicolons() {
        let merged = merge_into_args(
            &args(&["mod=@exile;"]),
            &extras(&["@arcas_dev_tools"], &[]),
            WINDOWS,
        );

        assert_eq!(merged, args(&["mod=@exile;@arcas_dev_tools;"]));
    }

    /// The launch line is rebuilt every run, so a mod already named in config.yml must not accumulate copies.
    #[test]
    fn a_mod_the_config_already_names_is_not_added_twice() {
        let merged = merge_into_args(
            &args(&["mod=@exile\\;@arcas_dev_tools\\;"]),
            &extras(&["@arcas_dev_tools"], &[]),
            LINUX,
        );

        assert_eq!(merged, args(&["mod=@exile\\;@arcas_dev_tools\\;"]));
    }

    #[test]
    fn a_config_naming_no_mod_argument_gains_one_rather_than_losing_the_mods() {
        let merged = merge_into_args(
            &args(&["world=empty"]),
            &extras(&["@arcas_dev_tools"], &["@arcas_dev_tools_server"]),
            LINUX,
        );

        assert_eq!(
            merged,
            args(&["world=empty", "mod=@arcas_dev_tools\\;", "servermod=@arcas_dev_tools_server\\;"])
        );
    }

    /// An unconfigured Windows host launches with nothing and reports itself through every mod being missing.
    #[test]
    fn no_arguments_stay_no_arguments() {
        let merged = merge_into_args(&[], &extras(&["@arcas_dev_tools"], &[]), WINDOWS);
        assert!(merged.is_empty());
    }

    #[test]
    fn nothing_discovered_leaves_the_arguments_untouched() {
        let original = args(&["mod=@exile\\;", "servermod=@exileserver\\;@esm\\;"]);
        assert_eq!(merge_into_args(&original, &ExtraMods::default(), LINUX), original);
    }
}
