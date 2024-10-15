use serde::{Deserialize, Serialize};
use serde_json::Value as JSONValue;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Error {
    // Controls how the error_message is treated
    #[serde(rename = "type")]
    pub error_type: ErrorType,

    #[serde(rename = "content")]
    pub error_content: String,
}

impl Error {
    pub fn new(error_type: ErrorType, error_content: String) -> Self {
        Self {
            error_type,
            error_content,
        }
    }

    pub fn code<S: AsRef<str>>(message: S) -> Self {
        Self::new(ErrorType::Code, message.as_ref().to_string())
    }

    pub fn message<S: AsRef<str>>(message: S) -> Self {
        Self::new(ErrorType::Message, message.as_ref().to_string())
    }

    pub fn from_arma(input: String) -> Result<Vec<Self>, String> {
        let input: JSONValue = match serde_json::from_str(&input) {
            Ok(v) => v,
            Err(e) => {
                return Err(format!(
                    "[error::from_arma] Failed to convert input into JSONValue. Reason: {e}. Input: {input:?}"
                ))
            }
        };

        let errors = crate::parser::validate_content(&input);
        let error_array = match errors.as_array() {
            Some(e) => e,
            None => return Err(format!("[error::from_arma] Failed to convert validated errors to array. Errors: \"{errors:?}\"")),
        };

        let mut errors: Vec<Error> = Vec::new();
        for error in error_array {
            let error = crate::parser::validate_content(error);
            let json = match serde_json::to_string(&error) {
                Ok(j) => j,
                Err(e) => return Err(format!("[error::from_arma] Failed to convert to final JSON. Reason: {e}. Error: \"{error:?}\"")),
            };

            match serde_json::from_str(&json) {
                Ok(e) => errors.push(e),
                Err(e) => return Err(format!("[error::from_arma] Failed to convert to Error. Reason: {e}. Error: \"{error:?}\" ")),
            };
        }

        Ok(errors)
    }
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.error_content)
    }
}

impl std::error::Error for Error {
    fn cause(&self) -> Option<&dyn std::error::Error> {
        Some(self)
    }
}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Self {
            error_type: ErrorType::Message,
            error_content: e.to_string(),
        }
    }
}

impl From<String> for Error {
    fn from(e: String) -> Self {
        Self {
            error_type: ErrorType::Message,
            error_content: e,
        }
    }
}

impl From<&str> for Error {
    fn from(e: &str) -> Self {
        Self {
            error_type: ErrorType::Code,
            error_content: e.to_string(),
        }
    }
}

impl From<std::num::ParseIntError> for Error {
    fn from(e: std::num::ParseIntError) -> Self {
        Self {
            error_type: ErrorType::Message,
            error_content: e.to_string(),
        }
    }
}

impl From<std::num::ParseFloatError> for Error {
    fn from(e: std::num::ParseFloatError) -> Self {
        Self {
            error_type: ErrorType::Message,
            error_content: e.to_string(),
        }
    }
}

impl From<mysql_async::Error> for Error {
    fn from(value: mysql_async::Error) -> Self {
        Self {
            error_type: ErrorType::Message,
            error_content: value.to_string(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "snake_case")]
pub enum ErrorType {
    // Treats the error_message as a locale error code.
    Code,

    // Treats the error_message as a normal string
    Message,
}

#[cfg(test)]
mod tests {
    use super::*;
    use arma_rs::IntoArma;
    use serde_json::json;

    #[test]
    fn it_converts_to_error_vec() {
        let input = json!([
            json!([json!(["type", "code"]), json!(["content", "SOME_CODE"]),]),
            json!([
                json!(["type", "message"]),
                json!(["content", "This is some message"])
            ])
        ])
        .to_arma()
        .to_string();

        let result: Result<Vec<Error>, String> = Error::from_arma(input);

        assert_eq!(
            result.unwrap(),
            vec![
                Error {
                    error_type: ErrorType::Code,
                    error_content: "SOME_CODE".to_string()
                },
                Error {
                    error_type: ErrorType::Message,
                    error_content: "This is some message".to_string()
                }
            ]
        );
    }
}
