use crate::Command;
use base64;
use chrono::Utc;
use crossbeam_channel::{Receiver, RecvTimeoutError};
use log::*;
use serde_json::json;
use std::{
    fs,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    thread,
    time::{self, Duration},
};
use url;
use ws::{
    connect, CloseCode, Error as WSError, Handler, Handshake, Message, Request, Result as WSResult,
    Sender as WSSender,
};

pub struct WebsocketClient {
    // The URL of the bot
    url: String,

    // The connection to the bot
    connection: WSSender,

    // The path of where the esm.key is located
    key_path: String,

    // The channel containing messages to send to the bot
    receiver: Receiver<String>,

    // Controls if the connection should stop processing messages and exit
    close_connection: Arc<AtomicBool>,
}

impl Handler for WebsocketClient {
    // Builds the request sent to the bot
    fn build_request(&mut self, url: &url::Url) -> WSResult<Request> {
        let mut request = Request::from_url(url)?;
        self.add_authorization_header(&mut request);
        self.add_version_header(&mut request);
        Ok(request)
    }

    // `on_open` will be called only after the WebSocket handshake is successful
    fn on_open(&mut self, _: Handshake) -> WSResult<()> {
        debug!("[websocket_client::on_open] Connected to Discord");
        self.listen();
        Ok(())
    }

    // A message from the bot
    fn on_message(&mut self, message: Message) -> WSResult<()> {
        info!(
            "[websocket_client::on_message] Received message: {}",
            message
        );

        // Convert the message to text. This should be a stringified JSON
        let message = match message.as_text() {
            Ok(text) => text,
            Err(e) => {
                error!(
                    "[websocket_client::on_message] Failed to convert message into text: {}",
                    e
                );
                return Err(e);
            }
        };

        // Convert into JSON
        let command: Command = match serde_json::from_str(&message) {
            Ok(json) => json,
            Err(e) => {
                // Since Box::new takes ownership of e, it has to be converted to a string first
                let error_string = e.to_string();
                error!(
                    "[websocket_client::on_message] Failed to convert message into json: {}",
                    e
                );

                // Because Rust.
                return Err(WSError::new(
                    ws::ErrorKind::Custom(Box::new(e)),
                    std::borrow::Cow::from(error_string),
                ));
            }
        };

        // Acknowledge the message before processing
        crate::BOT.send(
            Some(command.id.clone()),
            command.command_name.clone(),
            json!({ "_event": "before_execute", "_event_parameters": { "timestamp": Utc::now().timestamp() } }).to_string(),
        );

        self.execute_command(command);

        // Required response
        Ok(())
    }

    // Whenever an error occurs, this method will be called
    fn on_error(&mut self, err: WSError) {
        info!("[websocket_client::on_error] {:?}", err);
        // No connection: <Io(Os { code: 32, kind: BrokenPipe, message: "Broken pipe" })>
        // Key denied: WS Error <Protocol>: Handshake failed.

        self.connection.shutdown().unwrap();
        self.reconnect();
    }

    // Whenever the connection closes
    fn on_close(&mut self, code: CloseCode, reason: &str) {
        debug!(
            "[websocket_client::on_close] Connection closing due to ({:?}) {}",
            code, reason
        );

        self.connection.shutdown().unwrap();
        self.reconnect();
    }
}

impl WebsocketClient {
    // Attempt to connect to the bot
    pub fn connect(connection_url: String, receiver_channel: Receiver<String>) {
        thread::spawn(move || {
            connect(connection_url.clone(), |out| WebsocketClient {
                url: connection_url.clone(),
                connection: out,
                key_path: String::from("@ESM/esm.key"),
                receiver: receiver_channel.to_owned(),
                close_connection: Arc::new(AtomicBool::new(false)),
            })
            .unwrap();
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
                return error!(
                    "websocket_client::add_authorization_header] Failed to find esm.key"
                );
            }
        };

        // Create the authorization header
        let mut auth_header = vec![(
            "AUTHORIZATION".into(),
            format!("basic {}", base64::encode(file_contents.as_bytes()))
                .as_bytes()
                .to_vec(),
        )];

        // Add the new header to the headers on the request
        request.headers_mut().append(&mut auth_header);
    }

    fn add_version_header(&self, request: &mut Request) {
        let mut version_header = vec![(
            String::from("EXTENSION_VERSION"),
            env!("CARGO_PKG_VERSION").as_bytes().to_vec(),
        )];

        // Add the new header to the headers on the request
        request.headers_mut().append(&mut version_header);
    }

    // Creates a thread that listens to the receiver channel to send messages across the wire
    fn listen(&mut self) {
        let receiver = self.receiver.to_owned();
        let connection = self.connection.to_owned();
        let close_connection = Arc::clone(&self.close_connection);

        thread::spawn(move || loop {
            if close_connection.load(Ordering::SeqCst) {
                break;
            }

            let message = receiver.recv_timeout(Duration::from_millis(500));

            match message {
                Ok(message) => {
                    info!(
                        "[websocket_client::listen] Sending message to ESM: {}",
                        message
                    );
                    connection.send(message).unwrap_or_default()
                }
                Err(e) => match e {
                    RecvTimeoutError::Timeout => {}
                    e => warn!("{:?}", e),
                },
            }
        });
    }

    fn reconnect(&mut self) {
        self.close_connection.store(true, Ordering::SeqCst);
        let sleep_time = time::Duration::from_secs(5);
        thread::sleep(sleep_time);

        // Attempt to reconnect every 5 seconds in dev and 30 seconds in release. No max attempts
        WebsocketClient::connect(self.url.to_owned(), self.receiver.to_owned());
    }

    fn execute_command(&self, command: Command) {
        debug!("Executing command: {:?}", &command);

        match command.command_name.as_str() {
            "server_initialization" => crate::A3_SERVER.server_initialization(command),
            "post_initialization" => crate::A3_SERVER.post_initialization(command),
            _ => error!(
                "[websocket_client::execute_command] Invalid command received: {}",
                command.command_name
            ),
        }
    }
}
