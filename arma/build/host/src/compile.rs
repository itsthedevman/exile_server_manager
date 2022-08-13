use compiler::{Compiler, CompilerError, Data};
use regex::Captures;

type CompilerResult = Result<Option<String>, CompilerError>;

const REGEX_OS_PATH: &str = r"os_path!\((.+,?)?\)";
const REGEX_EQUAL_TYPE: &str = r"equal_type\?\((.+)?,\s*(ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_NOT_EQUAL_TYPE: &str = r"not_equal_type\?\((.+)?,\s*(ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_RV_TYPE: &str = r"rv_type!\((ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_GET: &str = r"get!\((.+)?,\s*(.+)?\)";
const REGEX_GET_WITH_DEFAULT: &str = r"get!\((.+),\s*(.+),\s*(.*)*\)";
const REGEX_LOG: &str = r#"(info|warn|debug|error)!\((.+)?\)"#;
const REGEX_LOG_WITH_ARGS: &str = r#"(info|warn|debug|error)!\((".+")*,*\s*(.*)*\)"#;

pub fn bind_replacements(compiler: &mut Compiler) {
    // The order of these matter
    compiler
        .replace(REGEX_OS_PATH, os_path)
        .replace(REGEX_NOT_EQUAL_TYPE, not_equal_type)
        .replace(REGEX_EQUAL_TYPE, equal_type)
        .replace(REGEX_RV_TYPE, rv_type)
        .replace(REGEX_GET_WITH_DEFAULT, hash_get)
        .replace(REGEX_GET, hash_get)
        .replace(REGEX_LOG_WITH_ARGS, log)
        .replace(REGEX_LOG, log);
}

// os_path!("my_mod", "some_dir") -> Windows: "my_mod\some_dir" - Linux: "my_mod/some_dir"
fn os_path(context: &Data, matches: &Captures) -> CompilerResult {
    let path_chunks: Vec<String> = match matches.get(1) {
        Some(c) => c
            .as_str()
            .split(',')
            .map(|p| p.trim().replace('"', ""))
            .collect(),
        None => {
            return Err(format!(
                "{} -> os_path! - Wrong number of arguments, given 0, expected 1+",
                context.file_path
            )
            .into())
        }
    };

    let separator = if context.target == "windows" {
        "\\"
    } else {
        "/"
    };

    // Windows: \my_addon\path
    // Linux: /my_addon/path
    Ok(Some(format!(
        "\"{}{}\"",
        separator,
        path_chunks.join(separator)
    )))
}

// equal_type?([], ARRAY) -> [] isEqualType []
// equal_type?(_some_var, HASH) -> _some_var isEqualType createHashMap
fn equal_type(context: &Data, matches: &Captures) -> CompilerResult {
    let comparee = match matches.get(1) {
        Some(c) => c.as_str(),
        None => {
            return Err(format!(
                "{} -> equal_type? - Wrong number of arguments, given 0, expected 2",
                context.file_path
            )
            .into())
        }
    };

    let arma_type = match matches.get(2) {
        Some(t) => match t.as_str() {
            "ARRAY" => "[]",
            "BOOL" => "false",
            "HASH" => "createHashMap",
            "STRING" => "\"\"",
            "NIL" => "nil",
            t => {
                return Err(format!(
                    "{} -> equal_type? - Unsupported type provided: {t}",
                    context.file_path
                )
                .into())
            }
        },
        None => {
            return Err(format!(
                "{} -> equal_type? - Wrong number of arguments, given 1, expected 2",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("{comparee} isEqualType {arma_type}")))
}

// not_equal_type?([], ARRAY) -> [] isEqualType []
// not_equal_type?(_some_var, HASH) -> _some_var isEqualType createHashMap
fn not_equal_type(context: &Data, matches: &Captures) -> CompilerResult {
    let comparee = match matches.get(1) {
        Some(c) => c.as_str(),
        None => {
            return Err(format!(
                "{} -> not_equal_type? - Wrong number of arguments, given 0, expected 2",
                context.file_path
            )
            .into())
        }
    };

    let arma_type = match matches.get(2) {
        Some(t) => match t.as_str() {
            "ARRAY" => "[]",
            "BOOL" => "false",
            "HASH" => "createHashMap",
            "STRING" => "\"\"",
            "NIL" => "nil",
            t => {
                return Err(format!(
                    "{} -> not_equal_type? - Unsupported type provided: {t}",
                    context.file_path
                )
                .into())
            }
        },
        None => {
            return Err(format!(
                "{} -> not_equal_type? - Wrong number of arguments, given 1, expected 2",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("!({comparee} isEqualType {arma_type})")))
}

// rv_type!(ARRAY) -> []
// rv_type!(HASH) -> createHashMap
fn rv_type(context: &Data, matches: &Captures) -> CompilerResult {
    Ok(Some(
        match matches.get(1) {
            Some(m) => match m.as_str() {
                "ARRAY" => "[]",
                "BOOL" => "false",
                "HASH" => "createHashMap",
                "STRING" => "\"\"",
                "NIL" => "nil",
                t => {
                    return Err(format!(
                        "{} -> rv_type! - Invalid type provided to type: {t}",
                        context.file_path
                    )
                    .into())
                }
            },
            None => {
                return Err(format!(
                    "{} -> rv_type! - Wrong number of arguments, given 0, expected 1",
                    context.file_path
                )
                .into())
            }
        }
        .into(),
    ))
}

// get!(_hash_map, "key") -> _hash_map getOrDefault ["key", nil];
// get!(createHashMap, "key", 1) -> createHashMap getOrDefault ["key", 1];
fn hash_get(context: &Data, matches: &Captures) -> CompilerResult {
    let hash_map = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> get! - Wrong number of arguments, given 0, expect 2..3",
                context.file_path
            )
            .into())
        }
    };

    let key = match matches.get(2) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> get! - Wrong number of arguments, given 1, expect 2..3",
                context.file_path
            )
            .into())
        }
    };

    let default = match matches.get(3) {
        Some(default) => default.as_str(),
        None => "nil",
    };

    Ok(Some(format!(
        "{} getOrDefault [{}, {}]",
        hash_map, key, default
    )))
}

// info!(_my_var) -> ["file_name", format["%1", _my_var], "info"] call ESMs_util_log;
// debug!("Its %1 me, %2", _a, "mario") -> ["file_name", format["Its %1 me, %2", _a, "mario"], "debug"] call ESMs_util_log;
fn log(context: &Data, matches: &Captures) -> CompilerResult {
    let log_level = matches.get(1).unwrap().as_str();
    let content = match matches.get(2) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> log! - Wrong number of arguments, given 0, expect 2..3",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(match matches.get(3) {
        Some(args) => format!(
            "[\"{}\", format[{}, {}], \"{}\"] call ESMs_util_log",
            context.file_name,
            content,
            args.as_str(),
            log_level
        ),
        None => format!(
            "[\"{}\", format[\"%1\", {}], \"{}\"] call ESMs_util_log",
            context.file_name, content, log_level
        ),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use compiler::Data;
    use regex::Regex;

    #[test]
    fn it_replaces_get() {
        let content = r#"
            private _hash_map = createHashMap;

            get!(_hash_map, "key");
        "#;

        let regex = Regex::new(REGEX_GET).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            match hash_get(&Data::default(), &capture).unwrap() {
                Some(result) => {
                    output = output.replace(capture.get(0).unwrap().as_str(), &result);
                }
                None => {}
            };
        }

        assert_eq!(
            output,
            r#"
            private _hash_map = createHashMap;

            _hash_map getOrDefault ["key", nil];
        "#
        )
    }

    #[test]
    fn it_replaces_get_with_default() {
        let content = r#"
            private _hash_map = createHashMap;

            get!(_hash_map, "key", "this is the default");
        "#;

        let regex = Regex::new(REGEX_GET_WITH_DEFAULT).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            match hash_get(&Data::default(), &capture).unwrap() {
                Some(result) => {
                    output = output.replace(capture.get(0).unwrap().as_str(), &result);
                }
                None => {}
            };
        }

        assert_eq!(
            output,
            r#"
            private _hash_map = createHashMap;

            _hash_map getOrDefault ["key", "this is the default"];
        "#
        )
    }

    #[test]
    fn it_replaces_log() {
        let content = r#"
            private _testing = "foo";

            warn!(_testing);
            error!([true, false]);
        "#;

        let regex = Regex::new(REGEX_LOG).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            match log(
                &Data {
                    target: "".into(),
                    file_path: "".into(),
                    file_name: "ESMs_compiler_test".into(),
                    file_extension: "".into(),
                },
                &capture,
            )
            .unwrap()
            {
                Some(result) => {
                    output = output.replace(capture.get(0).unwrap().as_str(), &result);
                }
                None => {}
            };
        }

        assert_eq!(
            output,
            r#"
            private _testing = "foo";

            ["ESMs_compiler_test", format["%1", _testing], "warn"] call ESMs_util_log;
            ["ESMs_compiler_test", format["%1", [true, false]], "error"] call ESMs_util_log;
        "#
        )
    }

    #[test]
    fn it_replaces_log_with_args() {
        let content = r#"
            private _testing = "foo";
            private _variables = "bar";

            debug!("Testing - %1bar - foo%2", _testing, _variables);
            info!("Logging %1", true);
        "#;

        let regex = Regex::new(REGEX_LOG_WITH_ARGS).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            match log(
                &Data {
                    target: "".into(),
                    file_path: "".into(),
                    file_name: "ESMs_compiler_test".into(),
                    file_extension: "".into(),
                },
                &capture,
            )
            .unwrap()
            {
                Some(result) => {
                    output = output.replace(capture.get(0).unwrap().as_str(), &result);
                }
                None => {}
            };
        }

        assert_eq!(
            output,
            r#"
            private _testing = "foo";
            private _variables = "bar";

            ["ESMs_compiler_test", format["Testing - %1bar - foo%2", _testing, _variables], "debug"] call ESMs_util_log;
            ["ESMs_compiler_test", format["Logging %1", true], "info"] call ESMs_util_log;
        "#
        )
    }
}
