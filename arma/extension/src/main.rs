extern crate log;

mod models;
mod websocket_client;

// use std::collections::HashMap;
// use models::arma_request::ArmaRequest;
use websocket_client::WebsocketClient;

fn main() {
    env_logger::init();

    WebsocketClient::connect_to_bot();
}
