use message_proc::Arma;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
#[serde(rename_all = "snake_case")]
pub struct Metadata {
    pub player: Option<Player>,
    pub target: Option<Player>,

    // Used by the bot, not needed on the client
    #[serde(skip)]
    server_id: Option<String>,
}

impl Default for Metadata {
    fn default() -> Self {
        Metadata {
            player: None,
            target: None,
            server_id: None,
        }
    }
}

impl arma_rs::FromArma for Metadata {
    fn from_arma(input: String) -> Result<Self, String> {
        crate::parser::Parser::from_arma(&input)
    }
}

#[derive(Serialize, Deserialize, Debug, Default, Clone, PartialEq, Eq, Arma)]
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
            json!([
                "player",
                json!([json!(["steam_uid", "123456789098765432"])])
            ]),
            json!(["server_id", "a_server_id"])
        ])
        .to_arma()
        .to_string();

        let expectation = Metadata {
            player: Some(Player {
                discord_id: None,
                discord_mention: None,
                discord_name: None,
                steam_uid: "123456789098765432".into(),
            }),
            target: None,
            server_id: None, // Doesn't serialize/deserialize
        };

        let result: Result<Metadata, String> = Parser::from_arma(&input);

        assert_eq!(result.unwrap(), expectation);
    }

    #[test]
    fn it_converts_to_arma() {
        let command = Metadata {
            player: Some(Player {
                discord_id: Some(String::from("id")),
                discord_mention: Some(String::from("mention")),
                discord_name: Some(String::from("name")),
                steam_uid: String::from("steam_uid"),
            }),
            target: None,
            server_id: None,
        };

        assert_eq!(
            command.to_arma().to_string(),
            "[[\"player\",[[\"discord_id\",\"id\"],[\"discord_mention\",\"mention\"],[\"discord_name\",\"name\"],[\"steam_uid\",\"steam_uid\"]]],[\"target\",null],[\"server_id\",null]]"
        );
    }
}
