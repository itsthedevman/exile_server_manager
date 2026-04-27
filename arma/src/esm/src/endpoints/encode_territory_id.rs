use super::*;

pub fn encode_territory_id(id: String) -> String {
    let encoded_id = DATABASE.hasher.encode(&id);
    trace!("[#encode_territory_id] - {id} -> {encoded_id}");

    encoded_id
}
