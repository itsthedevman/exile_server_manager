use std::net::ToSocketAddrs;
use std::sync::Arc;
use std::time::Duration;

use crate::{command::IncomingCommand, transfer::*, write_lock, Command, Database, NetworkCommand};
use colored::Colorize;
use common::BuildError;
use message_io::network::{Endpoint, NetEvent, Transport};
use message_io::node::{self, NodeHandler, NodeTask};
use parking_lot::RwLock;

pub struct Arma {
    pub build_path: String,
    pub server_path: String,
    pub server_args: String,
}

#[derive(Clone)]
pub struct Client {
    pub host: String,
    pub transfers: Arc<RwLock<Transfers>>,
    pub database: Arc<Database>,
    pub arma: Arc<Arma>,

    handler: Option<NodeHandler<()>>,
    endpoint: Option<Endpoint>,
    task: Arc<Option<NodeTask>>,
}

impl Client {
    pub fn new(args: crate::Args) -> Result<Self, BuildError> {
        let transfers = Arc::new(RwLock::new(Transfers::new()));
        let database = Arc::new(Database::new(args.database_uri)?);
        let arma = Arc::new(Arma {
            build_path: args.build_path,
            server_path: args.a3_server_path,
            server_args: args.a3_server_args,
        });

        Ok(Client {
            handler: None,
            endpoint: None,
            task: Arc::new(None),
            host: args.host,
            transfers,
            database,
            arma,
        })
    }

    pub fn connect(&mut self) {
        let (handler, listener) = node::split::<()>();

        // Move this to an argument that is passed into the program
        let server_addr = self.host.to_socket_addrs().unwrap().next().unwrap();
        let (server, _) = handler
            .network()
            .connect(Transport::FramedTcp, server_addr)
            .unwrap();

        self.handler = Some(handler);
        self.endpoint = Some(server);

        let mut client = self.clone();
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(_endpoint, established) => {
                if established {
                    println!("{} - Connected to {}", "success".green(), server_addr);
                    let message = NetworkCommand::new(Command::Hello);
                    client.send(message);
                } else {
                    println!("{} - Failed to connect to {}", "error".red(), server_addr);
                    client.on_disconnect();
                }
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_endpoint, input_data) => {
                let mut message: NetworkCommand = match serde_json::from_slice(input_data) {
                    Ok(c) => c,
                    Err(e) => {
                        let message = NetworkCommand::new(Command::Error(e.to_string()));
                        client.send(message);
                        return;
                    }
                };

                match IncomingCommand::execute(&client, &message.command) {
                    Ok(command) => {
                        message.command = command;
                        client.send(message);
                    }
                    Err(e) => {
                        message.command = Command::Error(e.to_string());
                        client.send(message);
                    }
                }
            }
            NetEvent::Disconnected(_endpoint) => {
                client.on_disconnect();
            }
        });

        self.task = Arc::new(Some(task));
    }

    fn send(&self, command: NetworkCommand) {
        let data = serde_json::to_vec(&command).unwrap();

        self.handler
            .as_ref()
            .unwrap()
            .network()
            .send(self.endpoint.unwrap(), &data);
    }

    fn on_disconnect(&mut self) {
        self.handler.as_ref().unwrap().stop();

        write_lock(&self.transfers, |mut writer| {
            writer.clear();
            Ok(true)
        })
        .unwrap();

        std::thread::sleep(Duration::from_secs(1));
        self.connect();
    }
}
