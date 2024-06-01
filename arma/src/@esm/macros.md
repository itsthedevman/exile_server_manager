# SQF compiler macros
The build tool for ESM supports macros that are expanded during compilation. These macro definitions are located in `src/build/host/src/compiler.rs`.

## Limitations
The supporting compiler system works on Regex and only support single line usage. I would love to fix this but other priorities come first.


## Macros

### `const!(constant_name)`
Replaced with the corresponding value defined in constants.jsonc

Example:
```sqf
const!("EXAMPLE_STRING")

// Becomes:
"Hello world!" // As defined in constants.jsonc
```

### `current_year!()`
Replaced with the current year at compile time. Used for copyright notices

Example:
```sqf
current_year!()

// Becomes:
2024 // The current year at writing
```

### `define_fn!(function_name)`
Replaced with the function definition array required by Exile's `fn_preInit.sqf`. This macro handles file path separator differences between Windows and Linux

Example:
```sqf
define_fn!("ESMs_util_test_myAwesomeFunction")

// On Windows
["ESMs_util_test_myAwesomeFunction", "\exile_server_manager\code\ESMs_util_test_myAwesomeFunction.sqf"]

// On Linux
["ESMs_util_test_myAwesomeFunction", "/exile_server_manager/code/ESMs_util_test_myAwesomeFunction.sqf"]
```

### `dig!(hash, keys...)`
A shorthand for calling ESMs_util_hashmap_dig. This function will recursively dig into the provided SQF HashMap to find the key. See ESMs_util_hashmap_dig for more information.

Example:
```sqf
dig!(_myHash, "foo", "bar")

// Becomes:
[_myHash, "foo", "bar"] call ESMs_util_hashmap_dig
```

### `empty?(object)`
Shorthand to check to see if the provided object is empty by doing a count comparison

Example:
```sqf
empty?(_myObject)

// Becomes:
count(_myObject) isEqualTo 0
```

### `!empty?(object)`
Shorthand for the negated version of empty above; not empty.

Example:
```sqf
!empty?(_myObject)

// Becomes:
count(_myObject) isNotEqualTo 0
```

### `file_name!()`
Replaced with the name of the current file without the extension

Example:
```sqf
file_name!()

// Becomes:
"macros" // For this file
```

### `get!(hashmap, value, ?default)`
Shorthand for getting a value from a HashMap. The default is optional and will use `nil` if not provided

Example:
```sqf
get!(_myHashMap, "foo")

// Becomes:
_myHashMap getOrDefault ["foo", nil]

////
get!(_myHashMap, "foo", 0)

// Becomes:
_myHashMap getOrDefault ["foo", 0]
```

Example:
```sqf
key?(_myHashMap, "foo")

// Becomes:
[_myHashMap, "foo"] call ESMs_util_hashmap_key
```

### `localize!(key_without_prefix, replacements...)`
Shorthand for the `localize` command. Supports string interpolation

Example:
```sqf
// Requires a stringtable entry of "STR_ESM_SomeLocaleKey"
localize!("SomeLocaleKey")

// Becomes:
localize "$STR_ESM_SomeLocaleKey"

///
// Requires a stringtable entry of "STR_ESM_KeyWithInterpolation"
localize!("KeyWithInterpolation", _someValueToInclude)

// Becomes:
format[localize "$STR_ESM_KeyWithInterpolation", _someValueToInclude]
```

### Logging macros: `<log_level>!(message, replacements...)`
A macro that supports logging based on the current logging level. Supports string interpolation and non-string objects

Example:
```sqf
trace!("This logs on trace")
debug!("This logs on debug")
info!("This logs on info")
warn!("This logs on warn")
error!("This logs on error")

// Becomes:
// macros because it will use the current file name
["macros", format["%1", "This logs on trace"], "trace"] call ESMs_util_log
["macros", format["%1", "This logs on debug"], "debug"] call ESMs_util_log
["macros", format["%1", "This logs on info"], "info"] call ESMs_util_log
["macros", format["%1", "This logs on warn"], "warn"] call ESMs_util_log
["macros", format["%1", "This logs on error"], "error"] call ESMs_util_log

////
debug!(_myObject)

// Becomes:
["macros", format["%1", _myObject], "debug"] call ESMs_util_log

////
info!("Wow! %1, so cool.", _playerName)

// Becomes:
["macros", format["Wow! %1, so cool.", _playerName], "info"] call ESMs_util_log
```

### `nil?(object)`
Shorthand to check to see if the provided object is nil

Example:
```sqf
nil?(_myObject)

// Becomes:
isNil "_myObject"
```

### `!nil?(object)`
Shorthand for the negated version of nil above; not nil.

Example:
```sqf
!nil?(_myVariable)

// Becomes:
!(isNil "_myVariable")
```

### `os_path!(path_fragments...)`
Replaced with a file path used to define the "file" attribute for CfgFunctions. This macro handles file path separator differences between Windows and Linux

Example:
```sqf
os_path!("my_mod", "code_directory")

// On Windows
"my_mod\code_directory"

// On Linux
"my_mod/code_directory"
```

### `returns_nil!(object)`
Shorthand to check to see if the provided object is nil and if it is, return `nil` explicitly.
In my testing, Arma will error if a variable containing `nil` if referenced, even for a return.
This is likely a bug and BIS _may_ fix it at some point making this not needed.

Example:
```sqf
returns_nil!(_myObject)

// Becomes:
if (isNil "_myObject") then { nil } else { _myObject }
```

### `rv_type!(TYPE)`
Shorthand for returning an object with the expected type. This is mostly used for the `params` command.
Valid types: ARRAY, BOOL, HASH, STRING, NIL

Example:
```sqf
rv_type!(ARRAY)
rv_type!(BOOL)
rv_type!(HASH)
rv_type!(STRING)
rv_type!(NIL)

// Becomes:
[]
false
createHashMap
""
nil
```

### `type?(object, TYPE)`
A shorthand for checking if an object is a particular type.
Valid types: ARRAY, BOOL, HASH, STRING, NIL

Example:
```sqf
type?(_myObject, STRING)

// Becomes:
_myObject isEqualType ""

////
type?(_myObject, ARRAY)

// Becomes:
_myObject isEqualType []
```

### `!type?(object, TYPE)`
A shorthand for a negated version of `type?` above.
Valid types: ARRAY, BOOL, HASH, STRING, NIL

Example:
```sqf
!type?(_myObject, STRING)

// Becomes:
!(_myObject isEqualType "")

////
type?(_myObject, ARRAY)

// Becomes:
!(_myObject isEqualType [])
```
