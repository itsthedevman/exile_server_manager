pub mod data;
pub mod error;
pub mod metadata;
pub mod parser;

use arma_rs::FromArma;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub use data::*;
pub use error::*;
pub use metadata::*;

// Numbers in Arma are best stored as Strings when sending across the wire to avoid precision loss.
// Use this type for any numbers
pub type NumberString = String;

/*
    {
        id: "",
        type: "",
        server_id: [],
        data: {
            type: "",
            content: {}
        },
        metadata: {
            type: "",
            content: {}
        },
        errors: []
    }
*/
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Message {
    pub id: Uuid,

    #[serde(rename = "type")]
    pub message_type: Type,

    #[serde(default, skip_serializing_if = "data_is_empty")]
    pub data: Data,

    #[serde(default, skip_serializing_if = "metadata_is_empty")]
    pub metadata: Metadata,

    #[serde(default, skip_serializing_if = "errors_is_empty")]
    pub errors: Vec<Error>,
}

fn data_is_empty(data: &Data) -> bool {
    matches!(data, Data::Empty)
}

fn metadata_is_empty(metadata: &Metadata) -> bool {
    matches!(metadata, Metadata::Empty)
}

fn errors_is_empty(errors: &[Error]) -> bool {
    errors.is_empty()
}

impl Message {
    pub fn new() -> Self {
        Message::default()
    }

    pub fn set_id(mut self, uuid: Uuid) -> Message {
        self.id = uuid;
        self
    }

    pub fn set_type(mut self, message_type: Type) -> Message {
        self.message_type = message_type;
        self
    }

    pub fn set_data(mut self, data: Data) -> Message {
        self.data = data;
        self
    }

    pub fn set_metadata(mut self, metadata: Metadata) -> Message {
        self.metadata = metadata;
        self
    }

    pub fn add_error_code<S>(self, code: S) -> Message
    where
        S: Into<String>,
    {
        self.add_error(ErrorType::Code, code)
    }

    pub fn add_error_message<S>(self, message: S) -> Message
    where
        S: Into<String>,
    {
        self.add_error(ErrorType::Message, message)
    }

    pub fn add_error<S>(mut self, error_type: ErrorType, error_content: S) -> Message
    where
        S: Into<String>,
    {
        let error = Error::new(error_type, error_content.into());
        self.errors.push(error);
        self
    }

    pub fn as_bytes(&self) -> Result<Vec<u8>, String> {
        match serde_json::to_vec(&self) {
            Ok(vec) => Ok(vec),
            Err(e) => Err(format!(
                "Failed to deserialize. Reason: {:?}. Message: {:#?}",
                e, self
            )),
        }
    }

    pub fn from_bytes(data: &[u8]) -> Result<Message, String> {
        match serde_json::from_slice(&data) {
            Ok(message) => Ok(message),
            Err(e) => Err(format!(
                "Failed to deserialize. Reason: {:?}. Message: {:#?}",
                e,
                String::from_utf8(data.to_vec()).unwrap_or(format!("Bytes: {:?}", data))
            )),
        }
    }

    //  [
    //      "id",
    //      "type",
    //      [
    //          ["type", "content"],
    //          ["data_type", [["key_1", "key_2"], ["value_1", "value_2"]]
    //      ],
    //      [
    //          ["type", "content"],
    //          ["metadata_type", [["key_1", "key_2"], ["value_1", "value_2"]]
    //      ],
    //      [
    //          [["type", "content"], ["code", "1"]],
    //          [["type", "content"], ["message", "This is an error"]]
    //      ]
    //  ]
    pub fn from_arma(
        id: String,
        message_type: String,
        data: String,
        metadata: String,
        errors: String,
    ) -> Result<Message, String> {
        // The message type has to be double quoted in order to parse
        let mut message = match serde_json::from_str(&format!("\"{}\"", message_type)) {
            Ok(t) => Self::new().set_type(t),
            Err(e) => {
                return Err(format!(
                    "\"{}\" is not a valid type. Error: {}",
                    message_type, e
                ))
            }
        };

        match Uuid::parse_str(&id) {
            Ok(uuid) => message.id = uuid,
            Err(e) => return Err(format!("Failed to extract ID from {:?}. {}", id, e)),
        };

        match Data::from_arma(data) {
            Ok(d) => message.data = d,
            Err(e) => return Err(e),
        };

        match Metadata::from_arma(metadata) {
            Ok(d) => message.metadata = d,
            Err(e) => return Err(e),
        };

        match Error::from_arma(errors) {
            Ok(e) => message.errors = e,
            Err(e) => return Err(e),
        };

        Ok(message)
    }
}

impl std::fmt::Display for Message {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", serde_json::to_string_pretty(&self).unwrap())
    }
}

impl Default for Message {
    fn default() -> Self {
        Message {
            id: Uuid::new_v4(),
            message_type: Type::Event,
            data: Data::Empty,
            metadata: Metadata::Empty,
            errors: Vec::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, PartialEq, Eq, Clone, Copy)]
#[serde(rename_all = "snake_case")]
pub enum Type {
    // Execute a Arma function
    Arma,

    // Bounces the message back
    Echo,

    // Regular events, such as Init, PostInit, etc.
    Event,

    // Database query
    Query,
}

////////////////////////////////////////////////////////////

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::Init;

    #[test]
    fn test_data_is_empty() {
        let result = data_is_empty(&Data::Empty);
        assert!(result);

        let server_init = Init {
            server_name: "server_name".into(),
            price_per_object: "10".into(),
            territory_lifetime: "7".into(),
            territory_data: "[]".into(),
            server_start_time: chrono::Utc::now(),
            extension_version: "2.0.0".into(),
            vg_enabled: false,
            vg_max_sizes: String::new(),
        };

        let result = data_is_empty(&Data::Init(server_init));
        assert!(!result);
    }

    #[test]
    fn test_metadata_is_empty() {
        let result = metadata_is_empty(&Metadata::Empty);
        assert!(result);
    }

    #[test]
    fn test_errors_is_empty() {
        let result = errors_is_empty(&Vec::new());
        assert!(result);

        let error = Error::new(ErrorType::Code, "1".into());
        let result = errors_is_empty(&[error]);
        assert!(!result);
    }

    #[test]
    fn test_serializing_empty_message() {
        let message = Message::new();
        let json = serde_json::to_string(&message).unwrap();

        let expected = format!("{{\"id\":\"{}\",\"type\":\"event\"}}", message.id);
        assert_eq!(json, expected);
    }

    #[test]
    fn test_deserializing_empty_message() {
        let uuid = Uuid::new_v4();
        let input = format!("{{\"id\":\"{}\",\"type\":\"event\"}}", uuid);
        let message: Message = serde_json::from_str(&input).unwrap();

        assert_eq!(message.id, uuid);
        assert!(matches!(message.data, Data::Empty));
        assert!(matches!(message.metadata, Metadata::Empty));
        assert!(message.errors.is_empty());
    }

    #[test]
    fn test_from_str() {
        use data::Data;

        let id = Uuid::new_v4();
        let expectation = Message::new()
            .set_id(id)
            .set_type(Type::Event)
            .set_data(Data::Test(data::Test {
                foo: "test\"ing".into(),
            }))
            .set_metadata(Metadata::Test(metadata::MetadataTest {
                foo: "\"testing\" \\(* \\\\\" *)/ - \"nested\"".into(),
            }))
            .add_error(ErrorType::Message, "This is a message")
            .add_error(ErrorType::Code, "CODING");

        let result = Message::from_arma(
            id.to_string(),
            "event".into(),
            r#"[["type","test"],["content",[["foo","test""ing"]]]]"#
            .to_string(),
            r#"[["type","test"],["content",[["foo","""testing"" \(* """""" *)/ - ""nested"""]]]]"#
            .to_string(),
            r#"[[["type","message"],["content","This is a message"]],[["type","code"],["content","CODING"]]]"#
            .to_string(),
        )
        .unwrap();

        assert_eq!(result.id, expectation.id);
        assert_eq!(result.data, expectation.data);
        assert_eq!(result.metadata, expectation.metadata);
        assert_eq!(result.errors, expectation.errors);
    }
}
