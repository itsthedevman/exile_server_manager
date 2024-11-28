use std::collections::HashSet;

use super::*;

#[derive(Debug, Serialize)]
struct Account {
    uid: String,
    name: String,
}

impl Account {
    pub fn new(uid: &str) -> Self {
        Account {
            uid: uid.to_owned(),
            name: String::new(),
        }
    }
}

#[derive(Debug, Serialize, Default)]
struct Territory {
    id: String,
    owner_uid: String,
    owner_name: String,
    territory_name: String,
    radius: f64,
    level: isize,
    flag_texture: String,
    flag_stolen: bool,
    last_paid_at: NaiveDateTime,
    build_rights: Vec<Account>,
    moderators: Vec<Account>,
    object_count: isize,
    esm_custom_id: Option<String>,
}

pub async fn player_territories(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let player_uid = match arguments.get("uid") {
        Some(uid) => uid,
        None => {
            return Err(QueryError::User(
                "Missing key `uid` in provided query arguments".into(),
            ));
        }
    };

    let result = connection
        .exec_map(
            &context.sql.player_territories,
            params! { "player_uid" => player_uid, "wildcard_uid" => format!("%{}%", player_uid) },
            map_results,
        )
        .await;

    match result {
        Ok(territories) => {
            if territories.is_empty() {
                return Ok(vec![]);
            }

            let errors = territories
                .iter()
                .filter_map(|result| result.as_ref().err())
                .map(|err| err.to_string())
                .collect::<Vec<String>>()
                .join(", ");

            if !errors.is_empty() {
                return Err(QueryError::System(format!("Query failed - {}", errors)));
            }

            let territories: Vec<Territory> =
                territories.into_iter().filter_map(Result::ok).collect();

            let territories: Vec<String> =
                update_id_and_names(context, connection, territories)
                    .await?
                    .into_iter()
                    .filter_map(|t| serde_json::to_string(&t).ok())
                    .collect();

            Ok(territories)
        }
        Err(e) => Err(QueryError::System(format!("Query failed - {}", e))),
    }
}

fn map_results(mut row: Row) -> Result<Territory, Error> {
    let account_converter = |data: &str| match serde_json::from_str::<Vec<String>>(data) {
        Ok(res) => Ok(res.iter().map(|uid| Account::new(&uid)).collect()),
        Err(e) => Err(e.to_string()),
    };

    let id: isize = select_column(&mut row, "id")?;
    let flag_stolen: isize = select_column(&mut row, "flag_stolen")?;
    let build_rights: String = select_column(&mut row, "build_rights")?;
    let moderators: String = select_column(&mut row, "moderators")?;

    let territory = Territory {
        id: id.to_string(),
        owner_uid: select_column(&mut row, "owner_uid")?,
        owner_name: select_column(&mut row, "owner_name")?,
        territory_name: select_column(&mut row, "territory_name")?,
        radius: select_column(&mut row, "radius")?,
        level: select_column(&mut row, "level")?,
        flag_texture: select_column(&mut row, "flag_texture")?,
        flag_stolen: flag_stolen == 1,
        last_paid_at: select_column(&mut row, "last_paid_at")?,
        build_rights: account_converter(&build_rights)?,
        moderators: account_converter(&moderators)?,
        object_count: select_column(&mut row, "object_count")?,
        esm_custom_id: select_column(&mut row, "esm_custom_id")?,
    };

    Ok(territory)
}

async fn update_id_and_names(
    context: &Database,
    connection: &mut Conn,
    mut territories: Vec<Territory>,
) -> Result<Vec<Territory>, QueryError> {
    let name_lookup = create_name_lookup(context, connection, &territories).await?;

    territories.iter_mut().for_each(|territory| {
        // Update the builder/moderator names
        for account in territory
            .build_rights
            .iter_mut()
            .chain(territory.moderators.iter_mut())
        {
            account.name = name_lookup
                .get(&account.uid)
                .cloned()
                .unwrap_or_else(|| "Name not found".to_string());
        }

        // Encode the ID
        territory.id = context.hasher.encode(&territory.id)
    });

    Ok(territories)
}

async fn create_name_lookup(
    context: &Database,
    connection: &mut Conn,
    territories: &Vec<Territory>,
) -> Result<HashMap<String, String>, QueryError> {
    let uids = territories
        .iter()
        .flat_map(|t| {
            t.build_rights
                .iter()
                .chain(t.moderators.iter())
                .map(|a| a.uid.to_string())
        })
        .collect::<HashSet<String>>() // Uniqueness
        .into_iter()
        .collect::<Vec<String>>();

    let query = replace_list(&context.sql.account_name_lookup, ":uids", uids.len());

    // Execute the query
    let name_lookup = connection.exec_map(&query, uids, |t| t).await;

    match name_lookup {
        Ok(l) => Ok(l.into_iter().collect::<HashMap<String, String>>()),
        Err(e) => return Err(QueryError::System(format!("Query failed - {}", e))),
    }
}
