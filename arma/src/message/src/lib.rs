pub mod error;
pub mod parser;

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

pub use error::*;

pub type Data = HashMap<String, Value>;

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

    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub data: Data,

    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub metadata: Data,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub errors: Vec<Error>,
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

    pub fn set_metadata(mut self, metadata: Data) -> Message {
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

        match crate::parser::Parser::from_arma(&data) {
            Ok(d) => message.data = d,
            Err(e) => return Err(e),
        };

        match crate::parser::Parser::from_arma(&metadata) {
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
            data: Data::default(),
            metadata: Data::default(),
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
    use serde_json::json;

    use super::*;

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
        assert!(message.data.is_empty());
        assert!(message.metadata.is_empty());
        assert!(message.errors.is_empty());
    }

    #[test]
    fn test_from_str() {
        let id = Uuid::new_v4();

        let expectation = Message::new()
            .set_id(id)
            .set_type(Type::Event)
            .set_data(Data::from([
                (String::from("key_1"), json!("value_1")),
                (String::from("key_2"), json!([json!("value_2")])),
            ]))
            .set_metadata(Data::from([
                (String::from("discord_id"), json!(null)),
                // This is never the case, but a great place to test some weird text
                (
                    String::from("discord_name"),
                    json!("\"testing\" \\(* \\\\\" *)/ - \"nested\""),
                ),
            ]))
            .add_error(ErrorType::Message, "This is a message")
            .add_error(ErrorType::Code, "CODING");

        let result = Message::from_arma(
            id.to_string(),
            "event".into(),
            r#"[["key_1","value_1"],["key_2", ["value_2"]]]"#
            .to_string(),
            r#"[["discord_id",null],["discord_name","""testing"" \(* """""" *)/ - ""nested"""]]"#
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
