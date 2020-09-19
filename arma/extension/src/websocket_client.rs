use ws::{connect, Handler, Sender, Handshake, Result, Message, CloseCode, Request, Error};
use url;
use std::fs;
use base64;
use log::debug;

const TEST_KEY: &str = "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d";

pub struct WebsocketClient {
    connection: Sender
}

impl Handler for WebsocketClient {
    // Builds the request sent to the bot
    fn build_request(&mut self, url: &url::Url) -> Result<Request> {
        let mut request = Request::from_url(url)?;
        self.add_authorization_header(&mut request);
        Ok(request)
    }

    // `on_open` will be called only after the WebSocket handshake is successful
    fn on_open(&mut self, _: Handshake) -> Result<()> {
        debug!("Connected to Discord");

        self.connection.send("Hello WebSocket")
    }

    // A message from the bot
    fn on_message(&mut self, msg: Message) -> Result<()> {
        // Close the connection when we get a response from the server
        println!("Got message: {}", msg);
        self.connection.close(CloseCode::Normal)
    }

    // Whenever an error occurs, this method will be called
    fn on_error(&mut self, err: Error) {
        debug!("[on_error] {:?}", err);
        // No connection: <Io(Os { code: 32, kind: BrokenPipe, message: "Broken pipe" })>

        // Attempt to reconnect every 5 seconds in dev and 30 seconds in release. No max attempts
        // WebsocketClient::connect_to_bot();
    }
}

impl WebsocketClient {
    // Attempt to connect to the bot
    pub fn connect_to_bot() {
        connect("ws://127.0.0.1:3001", |out| WebsocketClient { connection: out } ).unwrap()
    }

    // Takes in a Request and adds the esm.key into the headers for authorization
    fn add_authorization_header(&self, request: &mut Request) {
        // Read in the esm.key file
        // If file not found, Consider creating a ArmaServer struct that contains a log method to log to the A3 server
        // rv_callback!("esm", "ESM_fnc_log", "Failed to find ESM.key")

        // Create the authorization header
        let mut auth_header = vec![(
            "AUTHORIZATION".into(),
            format!("basic {}", base64::encode(TEST_KEY.as_bytes())).as_bytes().to_vec()
        )];

        // Add the new header to the headers on the request
        request.headers_mut().append(&mut auth_header);
    }
}
