use ws::{connect, Handler, Sender as WSSender, Handshake, Result as WSResult, Message, CloseCode, Request, Error as WSError};
use url;
use std::{fs, thread, time};
use crossbeam_channel::Receiver;
use base64;
use log::*;

pub struct WebsocketClient {
    url: String,
    connection: WSSender,
    key_path: String,
    receiver: Receiver<String>
}

impl Handler for WebsocketClient {
    // Builds the request sent to the bot
    fn build_request(&mut self, url: &url::Url) -> WSResult<Request> {
        let mut request = Request::from_url(url)?;
        self.add_authorization_header(&mut request);
        Ok(request)
    }

    // `on_open` will be called only after the WebSocket handshake is successful
    fn on_open(&mut self, _: Handshake) -> WSResult<()> {
        debug!("[on_open] Connected to Discord");
        self.listen();
        Ok(())
    }

    // A message from the bot
    fn on_message(&mut self, msg: Message) -> WSResult<()> {
        // Close the connection when we get a response from the server
        println!("[on_message] Got message: {}", msg);
        self.connection.close(CloseCode::Normal)
    }

    // Whenever an error occurs, this method will be called
    fn on_error(&mut self, err: WSError) {
        info!("[on_error] {:?}", err);
        // No connection: <Io(Os { code: 32, kind: BrokenPipe, message: "Broken pipe" })>
        // Key denied: WS Error <Protocol>: Handshake failed.

        let sleep_time = time::Duration::from_secs(5);
        thread::sleep(sleep_time);

        info!("Attempting reconnect...");

        // Attempt to reconnect every 5 seconds in dev and 30 seconds in release. No max attempts
        WebsocketClient::connect_to_bot(self.url.clone(), self.key_path.clone(), self.receiver.clone());
    }

    // Whenever the connection closes
    fn on_close(&mut self, code: CloseCode, reason: &str) {
        debug!("[on_close] Connection closing due to ({:?}) {}", code, reason);
    }
}

impl WebsocketClient {
    // Attempt to connect to the bot
    pub fn connect_to_bot(connection_url: String, key_path: String, receiver_channel: Receiver<String>) {
        thread::spawn(move || {
            connect(
                connection_url.clone(),
                |out| {
                WebsocketClient {
                    url: connection_url.clone(),
                    connection: out,
                    key_path: key_path.clone(),
                    receiver: receiver_channel.clone()
                }
            }).unwrap();
        });
    }

    // Takes in a Request and adds the esm.key into the headers for authorization
    fn add_authorization_header(&self, request: &mut Request) {
        // Read in the esm.key file
        let file = fs::read_to_string(self.key_path.clone());

        // Read the contents of the file result. If the file isn't found, panic!
        let file_contents = match file {
            Ok(contents) => contents,
            Err(_) => {
                return error!("Failed to find esm.key");
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

    // Creates a thread that listens to the receiver channel to send messages across the wire
    fn listen(&self) {
        let receiver = self.receiver.clone();
        let connection = self.connection.clone();

        thread::spawn(move || {
            loop {
                let message = receiver.recv();

                match message {
                    Ok(message) => connection.send(message).unwrap_or_default(),
                    Err(e) => debug!("{:?}", e),
                }
            }
        });
    }
}
