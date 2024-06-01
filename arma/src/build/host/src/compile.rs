use std::collections::HashMap;

use chrono::prelude::*;
use compiler::{Compiler, CompilerError, Data};
use json_comments::StripComments;
use lazy_static::lazy_static;
use regex::Captures;
use serde_json::Value;

lazy_static! {
    static ref CONSTANTS: HashMap<String, Value> = {
        let file_path = crate::builder::GIT_PATH
            .join("src")
            .join("@esm")
            .join("constants.jsonc");

        let contents = std::fs::read_to_string(file_path)
            .expect("Missing file esm_arma/src/@esm/constants.jsonc");

        // Remove the comments :(
        let contents = StripComments::new(contents.as_bytes());

        serde_json::from_reader(contents).expect("Failed to parse content in constants.jsonc")
    };
}

type CompilerResult = Result<Option<String>, CompilerError>;

const REGEX_CONST: &str = r#"const!\((\w+)\)"#;
const REGEX_CURRENT_YEAR: &str = r#"current_year!\(\)"#;
const REGEX_DEF_FN: &str = r#"define_fn!\("(\w+)?"\)"#;
const REGEX_DIG: &str = r#"dig!\((.+[^)])\)"#;
const REGEX_EMPTY_NEGATED: &str = r#"!empty\?\((\S+[^)])\)"#;
const REGEX_EMPTY: &str = r#"empty\?\((\S+[^)])\)"#;
const REGEX_FILE_NAME: &str = r#"file_name!\(\)"#;
const REGEX_GET_WITH_DEFAULT: &str = r"get!\((.+),\s*(.+),\s*(.+[^)])\)";
const REGEX_GET: &str = r"get!\((.+)?,\s*(.+[^)])?\)";
const REGEX_KEY: &str = r#"key\?\((.+[^)])\)"#;
const REGEX_LOCALIZE: &str = r#"localize!\("(\w+)"((?:,\s*[\w"]+)*)\)"#;
const REGEX_LOG_WITH_ARGS: &str = r#"(trace|info|warn|debug|error)!\((".+")*,\s*(.*)+\)"#;
const REGEX_LOG: &str = r#"(trace|info|warn|debug|error)!\((.+)?\)"#;
const REGEX_NIL_NEGATED: &str = r#"!nil\?\((\w+)?\)"#;
const REGEX_NIL: &str = r#"nil\?\((\w+)?\)"#;
const REGEX_OS_PATH: &str = r"os_path!\((.+,?)?\)";
const REGEX_RETURNS_NIL: &str = r#"returns_nil!\((\w+)\)"#;
const REGEX_RV_TYPE: &str = r"rv_type!\((ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_TYPE_CHECK_NEGATED: &str = r"!type\?\((.+)?,\s*(ARRAY|BOOL|HASH|STRING|NIL)?\)";
const REGEX_TYPE_CHECK: &str = r"type\?\((.+)?,\s*(ARRAY|BOOL|HASH|STRING|NIL)?\)";

pub fn bind_replacements(compiler: &mut Compiler) {
    // The order of these matter
    compiler
        .replace(REGEX_CURRENT_YEAR, current_year)
        .replace(REGEX_FILE_NAME, file_name)
        .replace(REGEX_DEF_FN, define_fn)
        .replace(REGEX_OS_PATH, os_path)
        .replace(REGEX_TYPE_CHECK_NEGATED, type_ne)
        .replace(REGEX_TYPE_CHECK, type_eq)
        .replace(REGEX_RV_TYPE, rv_type)
        .replace(REGEX_GET_WITH_DEFAULT, hash_get)
        .replace(REGEX_GET, hash_get)
        .replace(REGEX_DIG, hash_dig)
        .replace(REGEX_KEY, hash_key)
        .replace(REGEX_LOG_WITH_ARGS, log)
        .replace(REGEX_LOG, log)
        .replace(REGEX_RETURNS_NIL, returns_nil)
        .replace(REGEX_EMPTY, empty)
        .replace(REGEX_EMPTY_NEGATED, not_empty)
        .replace(REGEX_NIL_NEGATED, not_nil)
        .replace(REGEX_NIL, nil)
        .replace(REGEX_CONST, replace_const)
        .replace(REGEX_LOCALIZE, localize);
}

fn localize(context: &Data, matches: &Captures) -> CompilerResult {
    let locale_name = match matches.get(1) {
        Some(c) => c.as_str(),
        None => {
            return Err(format!(
                "{} -> localize! - Wrong number of arguments, given 0, expected 1",
                context.file_path
            )
            .into())
        }
    };

    let default = format!(r#"localize "$STR_ESM_{locale_name}""#);

    let result = match matches.get(2) {
        Some(c) => {
            // arguments string starts with ,\s* if matched
            let arguments = c.as_str();

            // This will match on nothing
            if arguments.is_empty() {
                default
            } else {
                format!(r#"format[localize "$STR_ESM_{locale_name}"{arguments}]"#)
            }
        }
        None => default,
    };

    Ok(Some(result))
}

fn file_name(context: &Data, _matches: &Captures) -> CompilerResult {
    Ok(Some(format!("{:?}", context.file_name)))
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

fn empty(context: &Data, matches: &Captures) -> CompilerResult {
    let contents = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> empty? - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("count({}) isEqualTo 0", contents)))
}

fn not_empty(context: &Data, matches: &Captures) -> CompilerResult {
    let contents = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> !empty? - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("count({}) isNotEqualTo 0", contents)))
}

fn returns_nil(context: &Data, matches: &Captures) -> CompilerResult {
    let variable = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> returns_nil! - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!(
        r#"if (isNil "{variable}") then {{ nil }} else {{ {variable} }}"#
    )))
}

fn not_nil(context: &Data, matches: &Captures) -> CompilerResult {
    let content = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> !nil? - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("!(isNil \"{content}\")")))
}

fn nil(context: &Data, matches: &Captures) -> CompilerResult {
    let content = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> nil? - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    Ok(Some(format!("isNil \"{content}\"")))
}

fn replace_const(context: &Data, matches: &Captures) -> CompilerResult {
    let content = match matches.get(1) {
        Some(m) => m.as_str(),
        None => {
            return Err(format!(
                "{} -> const! - Wrong number of arguments, given 0, expect 1",
                context.file_path
            )
            .into())
        }
    };

    // Load the constant
    let constant = match CONSTANTS.get(content) {
        Some(c) => c,
        None => return Ok(None),
    };

    let replacement = match constant {
        Value::Null => "nil".to_owned(),
        Value::Bool(b) => format!("{b}"),
        Value::Number(n) => format!("{n}"),
        Value::String(s) => format!("\"{s}\""),
        _ => {
            return Err(format!(
                "{} -> const! - Constant \"{constant}\" returns an object/array. These are not supported at this time",
                context.file_path
            )
            .into())
        }
    };

    // Replace
    Ok(Some(replacement))
}

fn current_year(_context: &Data, _matches: &Captures) -> CompilerResult {
    Ok(Some(format!("{}", chrono::Utc::now().year())))
}

#[cfg(test)]
mod tests {
    use super::*;
    use compiler::Data;
    use regex::Regex;

    #[macro_export]
    macro_rules! compile {
        ($code:expr, $regex:expr, $parsing_method:ident) => {{
            let regex = Regex::new($regex).unwrap();
            let captures: Vec<Captures> = regex.captures_iter($code).collect();

            let mut output = $code.to_string();
            for capture in captures {
                if let Some(result) = $parsing_method(&Data::default(), &capture).unwrap() {
                    output = output.replace(capture.get(0).unwrap().as_str(), &result);
                }
            }

            output
        }};

        ($code:expr, $regex:expr, $parsing_method:ident, $data:expr) => {{
            let regex = Regex::new($regex).unwrap();
            let captures: Vec<Captures> = regex.captures_iter($code).collect();

            let mut output = $code.to_string();
            for capture in captures {
                if let Some(result) = $parsing_method(&$data, &capture).unwrap() {
                    output = output.replace(capture.get(0).unwrap().as_str(), &result);
                }
            }

            output
        }};
    }

    #[test]
    fn it_replaces_localize() {
        let output = compile!(r#"localize!("Foo_Barrington")"#, REGEX_LOCALIZE, localize);
        assert_eq!(output, r#"localize "$STR_ESM_Foo_Barrington""#);
    }

    #[test]
    fn it_replaces_localize_format() {
        let output = compile!(
            r#"localize!("Foo_Barrington", _foo, _bar, "baz", false)"#,
            REGEX_LOCALIZE,
            localize
        );

        assert_eq!(
            output,
            r#"format[localize "$STR_ESM_Foo_Barrington", _foo, _bar, "baz", false]"#
        );
    }

    #[test]
    fn it_replaces_file_name() {
        let mut data = Data::default();
        data.file_name = "ESMs_test".into();

        let output = compile!(r#"file_name!()"#, REGEX_FILE_NAME, file_name, data);
        assert_eq!(output, r#""ESMs_test""#);
    }

    #[test]
    fn it_replaces_define_fn() {
        let output = compile!(
            r#"define_fn!("MY_Awesome_Method")"#,
            REGEX_DEF_FN,
            define_fn
        );

        assert_eq!(
            output,
            r#"["MY_Awesome_Method", "\exile_server_manager\code\MY_Awesome_Method.sqf"]"#
        );
    }

    #[test]
    fn it_replaces_type() {
        let output = compile!(r#"type?(_variable, STRING);"#, REGEX_TYPE_CHECK, type_eq);
        assert_eq!(output, r#"_variable isEqualType "";"#);
    }

    #[test]
    fn it_replaces_not_type() {
        let output = compile!(
            r#"!type?(VARIABLE, HASH);"#,
            REGEX_TYPE_CHECK_NEGATED,
            type_ne
        );
        assert_eq!(output, r#"!(VARIABLE isEqualType createHashMap);"#);
    }

    #[test]
    fn it_replaces_get() {
        let output = compile!(
            r#"
            private _hash_map = createHashMap;

            (get!(_hash_map, "key"));
        "#,
            REGEX_GET,
            hash_get
        );

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
        let output = compile!(
            r#"
            private _hash_map = createHashMap;

            get!(_hash_map, "key", "this is the default");
        "#,
            REGEX_GET_WITH_DEFAULT,
            hash_get
        );

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
        let output = compile!(
            r#"
            private _hash_map = createHashMap;

            dig!(_hash_map, "key_1");
            dig!(_hash_map, "key_1", "key_2");
            dig!([] call ESMs_util_hashmap_fromArray, "key1", _key2, "key_3");
        "#,
            REGEX_DIG,
            hash_dig
        );

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
        let output = compile!(
            r#"
            private _hash_map = createHashMap;

            key?(_hash_map, "key_1");
            key?(_hash_map, "key_1", "key_2");
            key?([] call ESMs_util_hashmap_fromArray, "key1", _key2, "key_3");
        "#,
            REGEX_KEY,
            hash_key
        );

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
        let output = compile!(
            r#"
            private _testing = "foo";

            trace!("Trace");
            debug!("Debug");
            info!("Info");
            warn!(_testing);
            error!([true, false]);
        "#,
            REGEX_LOG,
            log,
            Data {
                target: "".into(),
                file_path: "".into(),
                file_name: "ESMs_compiler_test".into(),
                file_extension: "".into(),
            }
        );

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
        let output = compile!(
            r#"
            private _testing = "foo";
            private _variables = "bar";

            debug!("Testing - %1bar - foo%2", _testing, _variables);
            info!("Logging %1", true);
        "#,
            REGEX_LOG_WITH_ARGS,
            log,
            Data {
                target: "".into(),
                file_path: "".into(),
                file_name: "ESMs_compiler_test".into(),
                file_extension: "".into(),
            }
        );

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
    fn it_replaces_empty() {
        let output = compile!(
            r#"
            empty?(_foo)
            (empty?([]))
            if ((empty?(foo)) then {};
        "#,
            REGEX_EMPTY,
            empty
        );

        assert_eq!(
            output,
            r#"
            count(_foo) isEqualTo 0
            (count([]) isEqualTo 0)
            if ((count(foo) isEqualTo 0) then {};
        "#
        )
    }

    #[test]
    fn it_replaces_not_empty() {
        let output = compile!(
            r#"
            !empty?(_foo)
            (!empty?([]))
            if ((!empty?(foo)) then {};
        "#,
            REGEX_EMPTY_NEGATED,
            not_empty
        );

        assert_eq!(
            output,
            r#"
            count(_foo) isNotEqualTo 0
            (count([]) isNotEqualTo 0)
            if ((count(foo) isNotEqualTo 0) then {};
        "#
        )
    }

    #[test]
    fn it_replaces_returns_nil() {
        let output = compile!(
            r#"returns_nil!(_variable);"#,
            REGEX_RETURNS_NIL,
            returns_nil
        );

        assert_eq!(
            output,
            r#"if (isNil "_variable") then { nil } else { _variable };"#
        )
    }

    #[test]
    fn it_replaces_nil() {
        let output = compile!(r#"nil?(_variable);"#, REGEX_NIL, nil);
        assert_eq!(output, r#"isNil "_variable";"#)
    }

    #[test]
    fn it_replaces_not_nil() {
        let output = compile!(r#"!nil?(_variable);"#, REGEX_NIL_NEGATED, not_nil);
        assert_eq!(output, r#"!(isNil "_variable");"#)
    }

    #[test]
    fn it_replaces_constants() {
        let output = compile!(r#"const!(EXAMPLE_STRING);"#, REGEX_CONST, replace_const);
        assert_eq!(output, r#""Hello world!";"#);

        let output = compile!(r#"const!(EXAMPLE_NUMBER);"#, REGEX_CONST, replace_const);
        assert_eq!(output, r#"69;"#);

        let output = compile!(r#"const!(EXAMPLE_BOOL);"#, REGEX_CONST, replace_const);
        assert_eq!(output, r#"false;"#)
    }

    #[test]
    fn it_replaces_current_year() {
        let output = compile!(r#"current_year!();"#, REGEX_CURRENT_YEAR, current_year);

        let regex = Regex::new(r"\d{4}").unwrap();
        assert!(regex.is_match(&output))
    }
}
