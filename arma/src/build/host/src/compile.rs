use compiler::{Compiler, CompilerError, Data};
use regex::Captures;

type CompilerResult = Result<Option<String>, CompilerError>;

const REGEX_OS_PATH: &str = r"os_path!\((.+,?)?\)";
const REGEX_EQUAL_TYPE: &str = r"type\?\((.+)?,\s*(ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_NOT_EQUAL_TYPE: &str = r"!type\?\((.+)?,\s*(ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_RV_TYPE: &str = r"rv_type!\((ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_GET: &str = r"get!\((.+)?,\s*(.+[^)])?\)";
const REGEX_GET_WITH_DEFAULT: &str = r"get!\((.+),\s*(.+),\s*(.*)*\)";
const REGEX_LOG: &str = r#"(trace|info|warn|debug|error)!\((.+)?\)"#;
const REGEX_LOG_WITH_ARGS: &str = r#"(trace|info|warn|debug|error)!\((".+")*,*\s*(.*)*\)"#;
const REGEX_NIL: &str = r#"nil\?\((\w+)?\)"#;
const REGEX_NOT_NIL: &str = r#"!nil\?\((\w+)?\)"#;
const REGEX_DEF_FN: &str = r#"define_fn!\("(\w+)?"\)"#;
const REGEX_ENV: &str = r#"(trace|info|warn|debug|error)\?"#;
const REGEX_DIG: &str = r#"dig!\((.+[^)])\)"#;
const REGEX_KEY: &str = r#"key\?\((.+[^)])\)"#;

pub fn bind_replacements(compiler: &mut Compiler) {
    // The order of these matter
    compiler
        .replace(REGEX_DEF_FN, define_fn)
        .replace(REGEX_OS_PATH, os_path)
        .replace(REGEX_NOT_EQUAL_TYPE, type_ne)
        .replace(REGEX_EQUAL_TYPE, type_eq)
        .replace(REGEX_RV_TYPE, rv_type)
        .replace(REGEX_GET_WITH_DEFAULT, hash_get)
        .replace(REGEX_GET, hash_get)
        .replace(REGEX_DIG, hash_dig)
        .replace(REGEX_KEY, hash_key)
        .replace(REGEX_ENV, env)
        .replace(REGEX_LOG_WITH_ARGS, log)
        .replace(REGEX_LOG, log)
        .replace(REGEX_NOT_NIL, not_nil)
        .replace(REGEX_NIL, nil);
}

// define_fn!("ESMs_util_log") -> ["ESMs_util_log", "exile_server_manager\code\ESMs_util_log.sqf"]
// Also replaces slashes based on OS
fn define_fn(context: &Data, matches: &Captures) -> CompilerResult {
    let function_name = match matches.get(1) {
        Some(c) => c.as_str(),
        None => {
            return Err(format!(
                "{} -> define_fn! - Wrong number of arguments, given 0, expected 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!(
        "[\"{function_name}\", \"{sep}exile_server_manager{sep}code{sep}{function_name}.sqf\"]",
        sep = "\\"
    )))
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

    let separator = "\\";

    // Windows: \my_addon\path
    // Linux: my_addon\path
    Ok(Some(format!(
        "\"{separator}{}\"",
        path_chunks.join(separator)
    )))
}

// type?([], ARRAY) -> [] isEqualType []
// type?(_some_var, HASH) -> _some_var isEqualType createHashMap
fn type_eq(context: &Data, matches: &Captures) -> CompilerResult {
    let comparee = match matches.get(1) {
        Some(c) => c.as_str(),
        None => {
            return Err(format!(
                "{} -> type? - Wrong number of arguments, given 0, expected 2",
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
                    "{} -> type? - Unsupported type provided: {t}",
                    context.file_path
                )
                .into())
            }
        },
        None => {
            return Err(format!(
                "{} -> type? - Wrong number of arguments, given 1, expected 2",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("{comparee} isEqualType {arma_type}")))
}

// !type?([], ARRAY) -> !([] isEqualType [])
// !type?(_some_var, HASH) -> !(_some_var isEqualType createHashMap)
fn type_ne(context: &Data, matches: &Captures) -> CompilerResult {
    let comparee = match matches.get(1) {
        Some(c) => c.as_str(),
        None => {
            return Err(format!(
                "{} -> !type? - Wrong number of arguments, given 0, expected 2",
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
                    "{} -> !type? - Unsupported type provided: {t}",
                    context.file_path
                )
                .into())
            }
        },
        None => {
            return Err(format!(
                "{} -> !type? - Wrong number of arguments, given 1, expected 2",
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

fn hash_dig(context: &Data, matches: &Captures) -> CompilerResult {
    let contents = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> dig! - Wrong number of arguments, given 0, expect 1..",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("[{}] call ESMs_util_hashmap_dig", contents)))
}

fn hash_key(context: &Data, matches: &Captures) -> CompilerResult {
    let contents = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> key? - Wrong number of arguments, given 0, expect 1..",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("[{}] call ESMs_util_hashmap_key", contents)))
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

fn env(_context: &Data, matches: &Captures) -> CompilerResult {
    let log_level = matches.get(1).unwrap().as_str();
    Ok(Some(format!("ESM_LogLevel isEqualTo \"{log_level}\"")))
}

fn not_nil(context: &Data, matches: &Captures) -> CompilerResult {
    let context = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> !nil? - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("!(isNil \"{context}\")")))
}

fn nil(context: &Data, matches: &Captures) -> CompilerResult {
    let context = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> nil? - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("isNil \"{context}\"")))
}

#[cfg(test)]
mod tests {
    use super::*;
    use compiler::Data;
    use regex::Regex;

    #[test]
    fn it_replaces_define_fn() {
        let content = r#"define_fn!("MY_Awesome_Method")"#;

        let regex = Regex::new(REGEX_DEF_FN).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = define_fn(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(
            output,
            r#"["MY_Awesome_Method", "\exile_server_manager\code\MY_Awesome_Method.sqf"]"#
        );
    }

    #[test]
    fn it_replaces_type() {
        let content = r#"type?(_variable, STRING);"#;

        let regex = Regex::new(REGEX_EQUAL_TYPE).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = type_eq(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(output, r#"_variable isEqualType "";"#);
    }

    #[test]
    fn it_replaces_not_type() {
        let content = r#"!type?(VARIABLE, HASH);"#;

        let regex = Regex::new(REGEX_NOT_EQUAL_TYPE).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = type_ne(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(output, r#"!(VARIABLE isEqualType createHashMap);"#);
    }

    #[test]
    fn it_replaces_get() {
        let content = r#"
            private _hash_map = createHashMap;

            (get!(_hash_map, "key"));
        "#;

        let regex = Regex::new(REGEX_GET).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = hash_get(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(
            output,
            r#"
            private _hash_map = createHashMap;

            (_hash_map getOrDefault ["key", nil]);
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
            if let Some(result) = hash_get(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
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
    fn it_replaces_hash_dig() {
        let content = r#"
            private _hash_map = createHashMap;

            dig!(_hash_map, "key_1");
            dig!(_hash_map, "key_1", "key_2");
            dig!([] call ESMs_util_hashmap_fromArray, "key1", _key2, "key_3");
        "#;

        let regex = Regex::new(REGEX_DIG).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = hash_dig(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(
            output,
            r#"
            private _hash_map = createHashMap;

            [_hash_map, "key_1"] call ESMs_util_hashmap_dig;
            [_hash_map, "key_1", "key_2"] call ESMs_util_hashmap_dig;
            [[] call ESMs_util_hashmap_fromArray, "key1", _key2, "key_3"] call ESMs_util_hashmap_dig;
        "#
        )
    }

    #[test]
    fn it_replaces_hash_key() {
        let content = r#"
            private _hash_map = createHashMap;

            key?(_hash_map, "key_1");
            key?(_hash_map, "key_1", "key_2");
            key?([] call ESMs_util_hashmap_fromArray, "key1", _key2, "key_3");
        "#;

        let regex = Regex::new(REGEX_KEY).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = hash_key(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(
            output,
            r#"
            private _hash_map = createHashMap;

            [_hash_map, "key_1"] call ESMs_util_hashmap_key;
            [_hash_map, "key_1", "key_2"] call ESMs_util_hashmap_key;
            [[] call ESMs_util_hashmap_fromArray, "key1", _key2, "key_3"] call ESMs_util_hashmap_key;
        "#
        )
    }

    #[test]
    fn it_replaces_log() {
        let content = r#"
            private _testing = "foo";

            trace!("Trace");
            debug!("Debug");
            info!("Info");
            warn!(_testing);
            error!([true, false]);
        "#;

        let regex = Regex::new(REGEX_LOG).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = log(
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
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(
            output,
            r#"
            private _testing = "foo";

            ["ESMs_compiler_test", format["%1", "Trace"], "trace"] call ESMs_util_log;
            ["ESMs_compiler_test", format["%1", "Debug"], "debug"] call ESMs_util_log;
            ["ESMs_compiler_test", format["%1", "Info"], "info"] call ESMs_util_log;
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
            if let Some(result) = log(
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
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
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

    #[test]
    fn it_replaces_env() {
        let content = r#"
            if (trace?) exitWith {};
            if (debug?) exitWith {};
            if (info?) exitWith {};
            if (warn?) exitWith {};
            if (error?) exitWith {};
        "#;

        let regex = Regex::new(REGEX_ENV).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = env(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(
            output,
            r#"
            if (ESM_LogLevel isEqualTo "trace") exitWith {};
            if (ESM_LogLevel isEqualTo "debug") exitWith {};
            if (ESM_LogLevel isEqualTo "info") exitWith {};
            if (ESM_LogLevel isEqualTo "warn") exitWith {};
            if (ESM_LogLevel isEqualTo "error") exitWith {};
        "#
        )
    }

    #[test]
    fn it_replaces_nil() {
        let content = r#"nil?(_variable);"#;

        let regex = Regex::new(REGEX_NIL).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = nil(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(output, r#"isNil "_variable";"#)
    }

    #[test]
    fn it_replaces_not_nil() {
        let content = r#"!nil?(_variable);"#;

        let regex = Regex::new(REGEX_NOT_NIL).unwrap();
        let captures: Vec<Captures> = regex.captures_iter(content).collect();

        let mut output = content.to_string();
        for capture in captures {
            if let Some(result) = not_nil(&Data::default(), &capture).unwrap() {
                output = output.replace(capture.get(0).unwrap().as_str(), &result);
            }
        }

        assert_eq!(output, r#"!(isNil "_variable");"#)
    }
}
