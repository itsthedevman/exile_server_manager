use arma_rs::{FromArma, IntoArma, Value as ArmaValue};
use message_proc::Arma;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum Metadata {
    Empty,
    Test(MetadataTest),
    Command(Command),
}

impl Default for Metadata {
    fn default() -> Self {
        Metadata::Empty
    }
}

impl IntoArma for Metadata {
    fn to_arma(&self) -> ArmaValue {
        match self {
            Metadata::Empty => ArmaValue::Null,
            Metadata::Test(t) => t.to_arma(),
            Metadata::Command(c) => c.to_arma(),
        }
    }
}

impl FromArma for Metadata {
    fn from_arma(input: String) -> Result<Self, String> {
        crate::parser::Parser::from_arma(&input)
    }
}

impl std::fmt::Display for Metadata {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match &self {
            Metadata::Empty => write!(f, "Empty"),
            Metadata::Test(d) => write!(f, "{:?}", d),
            Metadata::Command(d) => write!(f, "{:?}", d),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct MetadataTest {
    pub foo: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Command {
    pub player: Player,
    pub target: Option<Player>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Player {
    pub discord_id: Option<String>,
    pub discord_mention: Option<String>,
    pub discord_name: Option<String>,
    pub steam_uid: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::Parser;
    use arma_rs::IntoArma;
    use serde_json::json;

    #[test]
    fn it_converts_to_metadata_struct() {
        let input = json!([
            json!(["type", "test"]),
            json!(["content", json!([json!(["foo", "bar"])])])
        ])
        .to_arma()
        .to_string();

        let result: Result<Metadata, String> = Parser::from_arma(&input);

        assert_eq!(
            result.unwrap(),
            Metadata::Test(MetadataTest {
                foo: "bar".to_string()
            })
        );
    }

    #[test]
    fn it_converts_to_arma() {
        let command = Command {
            player: Player {
                discord_id: Some(String::from("id")),
                discord_mention: Some(String::from("mention")),
                discord_name: Some(String::from("name")),
                steam_uid: String::from("steam_uid"),
            },
            target: None,
        };

        assert_eq!(
            command.to_arma().to_string(),
            "[[\"player\",[[\"discord_id\",\"id\"],[\"discord_mention\",\"mention\"],[\"discord_name\",\"name\"],[\"steam_uid\",\"steam_uid\"]]],[\"target\",null]]"
        );
    }
}
