use indexmap::IndexMap;
use serde::Serialize;
use serde_json::json;
use std::path::PathBuf;

#[derive(Serialize)]
struct NameAttribute {
    name: String,
}

#[derive(Serialize)]
struct IDAttribute {
    #[serde(rename = "ID")]
    id: String,
}

#[derive(Serialize)]
struct Key {
    #[serde(rename = "$")]
    attributes: IDAttribute,

    #[serde(rename = "_")]
    pub comment: String,

    #[serde(flatten)]
    pub languages: IndexMap<String, String>,
}

impl Key {
    pub fn new(id: &str) -> Self {
        Key {
            attributes: IDAttribute {
                id: format!("STR_ESM_{id}"),
            },
            comment: String::new(),
            languages: IndexMap::new(),
        }
    }
}

#[derive(Serialize)]
struct Container {
    #[serde(rename = "$")]
    attributes: NameAttribute,

    #[serde(rename = "Key")]
    pub keys: Vec<Key>,
}

impl Container {
    pub fn new(name: String) -> Self {
        Container {
            attributes: NameAttribute { name },
            keys: vec![],
        }
    }
}

pub fn convert_yaml_to_xml(string_table_path: PathBuf) -> Result<String, String> {
    let file_content = match std::fs::read_to_string(&string_table_path) {
        Ok(c) => c,
        Err(_) => {
            return Err(format!(
                "Failed to read stringtable.yml. Path: {}",
                string_table_path.display()
            )
            .into());
        }
    };

    // There isn't a good crate that supports going from YAML to XML directly
    // So we have to convert the YML to JSON and modify it so xml2json can convert it to XML
    let json_hash: IndexMap<String, Vec<IndexMap<String, serde_json::Value>>> =
        match serde_yaml::from_str(&file_content) {
            Ok(j) => j,
            Err(e) => return Err(format!("Failed to parse YAML. {e}")),
        };

    /*
        // Represents a single Key
        {
            "ESMs_command_upgrade": [
                Object {
                    "id": String("Upgrade_StolenFlag"),
                    "arguments": Array [String("Player mention"), String("Territory ID")],
                    "english": String("%1, the territory flag for `%2` has been stolen! You need to get it back before you can upgrade your base")
                }
            ]
        }
    */
    let containers: Vec<Container> = json_hash
        .into_iter()
        .map(|(container_key, mut container_value)| {
            let mut container = Container::new(container_key);

            let keys = container_value
                .iter_mut()
                .map(|entry| {
                    // Remove id and arguments because the rest of the keys are languages
                    let id = entry.shift_remove("id".into()).expect("Missing ID for {entry:?}");

                    let id = id
                        .as_str()
                        .expect("Invalid data type for ID. Expected String");

                    let arguments = entry
                        .shift_remove("arguments".into())
                        .unwrap_or(json!([]));

                    let arguments = arguments
                        .as_array()
                        .expect("Invalid data type for arguments. Expected Array");

                    let mut stringtable_entry = Key::new(id);

                    // Build the argument comment
                    // <!-- %1 - Argument | %2 - Argument -->
                    let mut argument_comment = arguments
                        .iter()
                        .enumerate()
                        .map(|(index, argument)| {
                            // %1 - Something
                            format!(
                                "%{} - {}",
                                index + 1,
                                argument
                                    .as_str()
                                    .expect("Invalid data type for {id}'s arguments at position {index}. Expected String.")
                            )
                        })
                        .collect::<Vec<String>>()
                        .join(" | ");

                    // Default to "None" if there are none
                    if argument_comment.is_empty() {
                        argument_comment.push_str("None");
                    }

                    stringtable_entry.comment = format!("<!-- {argument_comment} -->");

                    // Insert the languages
                    entry.iter().for_each(|(key, value)| {
                        let value = value
                            .as_str()
                            .expect("Invalid data type for language value. Expected String");

                        stringtable_entry.languages.insert(
                            uppercase_first_character_maybe(key),
                            value.into()
                        );
                    });

                    stringtable_entry
                })
                .collect();

            container.keys = keys;
            container
        })
        .collect();

    // convert everything into the final JSON structure
    let stringtable_json = json!({
        "Project": {
            "$": {"name": "ESM"},
            "Package": {
                "$": {"name": "Exile_Server_Manager"},
                "Container": containers
            }
        }
    });

    // N-n-neat
    let mut xml_builder = xml2json_rs::XmlConfig::new()
        .rendering(xml2json_rs::Indentation::new(b'\t', 1))
        .decl(xml2json_rs::Declaration::new(
            xml2json_rs::Version::XML10,
            Some(xml2json_rs::Encoding::UTF8),
            None,
        ))
        .finalize();

    match xml_builder.build_from_json(&stringtable_json) {
        Ok(xml) => {
            // Remove the stringtable.yml from build
            if let Err(e) = std::fs::remove_file(&string_table_path) {
                return Err(format!(
                    "Failed to delete {}. Reason: {}",
                    string_table_path.display(),
                    e
                )
                .into());
            }

            Ok(xml)
        }
        Err(e) => Err(format!("Failed to convert stringtable.yml to xml. Reason: {e}").into()),
    }
}

// https://stackoverflow.com/a/38406885
fn uppercase_first_character_maybe(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}
