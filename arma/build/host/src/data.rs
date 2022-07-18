use common::BuildError;
use serde::{Deserialize, Serialize};
use vfs::VfsPath;

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct DevUser {
    /// The dev user's Discord ID
    pub id: String,

    /// The dev user's Steam ID
    pub steam_uid: String,
}

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct Server {
    /// The Discord server's ID
    pub server_id: String,

    /// The Discord server channel's ID that ESM can log to
    pub logging_channel_id: String,

    /// The Discord IDs of the channels ESM can use in this Discord server
    pub channels: Vec<String>,

    /// The Discord IDs of the users ESM can use to send messages to
    pub users: Vec<String>,

    /// The Discord IDs of the users who have a particular role
    pub role_users: Vec<RoleUser>,
}

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct RoleUser {
    /// The user's Discord ID
    pub id: String,

    /// The server's role ID that this user has
    pub role_id: String,
}

// TODO: refactor "primary" and "secondary" to a list of servers
#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct Data {
    /// The dev user (i.e, you)
    pub dev: DevUser,

    /// The "primary" server
    pub primary: Server,

    /// The "secondary" server
    pub secondary: Server,

    /// A list of Steam UIDs to assign and use
    pub steam_uids: Vec<String>,
}

pub fn parse_data_file(path: VfsPath) -> Result<Data, BuildError> {
    let contents = match path.read_to_string() {
        Ok(c) => c,
        Err(e) => {
            return Err(format!(
                "{} - Could not find/read test_data.yml. Have you created/sym linked it yet?",
                e
            )
            .into())
        }
    };

    match serde_yaml::from_str(&contents) {
        Ok(c) => Ok(c),
        Err(e) => Err(e.to_string().into()),
    }
}
