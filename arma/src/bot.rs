use crate::websocket_client::WebsocketClient;
use crate::bot_command::BotCommand;
use log::*;
use crossbeam_channel::{unbounded, Receiver, Sender};

pub struct Bot {
    pub ready: bool,
    send_queue: Sender<String>,
}

impl Bot {
    pub fn new() -> Bot {
        // Any commands to be sent to the bot will use this channel set. These are Multiple Sender, Multiple Receiver channels
        let (sender, receiver) = unbounded();

        // The one, the only.
        let esm_bot = Bot { send_queue: sender, ready: false, };

        // Connect to the bot
        esm_bot.connect(receiver);

        esm_bot
    }

    pub fn send(&self, id: Option<String>, command_name: String, parameters: String) {
        let command = BotCommand::new(id, command_name, parameters);
        let channel = self.send_queue.clone();

        match channel.send(command.into_json()) {
            Ok(_) => (),
            Err(err) => error!("Failed to send message to bot: {}", err),
        }
    }

    fn connect(&self, receiver: Receiver<String>) {
        let ws_url = crate::CONFIG[0]["ws_url"].as_str().unwrap().to_string();

        WebsocketClient::connect(ws_url, receiver);
    }
}
