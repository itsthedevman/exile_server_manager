use ws::{connect, Handler, Sender, Handshake, Result, Message, CloseCode, Request, Error};
use url;
use std::{env, fs};
use base64;
use log::*;

pub struct WebsocketClient {
    connection: Sender,
    ext_path: String
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

        Ok(())
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
    pub fn connect_to_bot(ext_path: &String) {
        connect(
            env::var("ESM_WS_URL").unwrap_or("ws://ws.esmbot.com".to_string()),
            |out| {
            WebsocketClient {
                connection: out,
                ext_path: ext_path.clone()
            }
        }).unwrap()
    }

    // Takes in a Request and adds the esm.key into the headers for authorization
    fn add_authorization_header(&self, request: &mut Request) {
        // Read in the esm.key file
        let file = fs::read_to_string(format!("{}/esm.key", self.ext_path));

        // Read the contents of the file result. If the file isn't found, panic!
        let file_contents = match file {
            Ok(contents) => contents,
            Err(_) => {
                panic!("esm.key not found. Please read the documentation");
            }
        };

        // Create the authorization header
        // TODO: Remove the need to have the `arma_server` prefix
        let mut auth_header = vec![(
            "AUTHORIZATION".into(),
            format!(
                "basic {}",
                base64::encode(
                    format!("arma_server:{}", file_contents).as_bytes()
                )
            ).as_bytes().to_vec()
        )];

        // Add the new header to the headers on the request
        request.headers_mut().append(&mut auth_header);
    }
}
