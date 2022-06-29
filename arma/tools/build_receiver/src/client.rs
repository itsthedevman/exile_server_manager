use std::net::ToSocketAddrs;
use std::process::Command;
use std::sync::Arc;
use std::time::Duration;

use crate::{transfer::*, BuildError, BuildResult, NetworkCommands};
use colored::Colorize;
use message_io::network::{Endpoint, NetEvent, Transport};
use message_io::node::{self, NodeHandler, NodeTask};

#[derive(Clone)]
pub struct Client {
    pub host: String,
    pub transfers: Arc<Transfers>,

    handler: Option<NodeHandler<()>>,
    endpoint: Option<Endpoint>,
    task: Arc<Option<NodeTask>>,
}

impl Client {
    pub fn new(host: String) -> Self {
        let transfers = Arc::new(Transfers::new());

        Client {
            handler: None,
            endpoint: None,
            task: Arc::new(None),
            host,
            transfers,
        }
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
                    println!("Connected to build host @ {}", server_addr);
                    client.send(NetworkCommands::Hello);
                } else {
                    println!("Failed to connect to build host @ {}", server_addr);
                    client.on_disconnect();
                }
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_endpoint, input_data) => {
                // println!("{:?}", String::from_utf8_lossy(input_data));
                let message: NetworkCommands = match serde_json::from_slice(input_data) {
                    Ok(c) => c,
                    Err(e) => return client.send(NetworkCommands::Error(e.to_string())),
                };

                // println!("Inbound message:\n{:?}", message);
                match IncomingCommand::execute(&client, &message) {
                    Ok(_) => {
                        client.send(NetworkCommands::Success);
                    }
                    Err(e) => {
                        client.send(NetworkCommands::Error(e.to_string()));
                    }
                }
            }
            NetEvent::Disconnected(_endpoint) => {
                client.on_disconnect();
            }
        });

        self.task = Arc::new(Some(task));
    }

    fn send(&self, command: NetworkCommands) {
        let data = serde_json::to_vec(&command).unwrap();
        self.handler
            .as_ref()
            .unwrap()
            .network()
            .send(self.endpoint.unwrap(), &data);
    }

    fn on_disconnect(&mut self) {
        self.handler.as_ref().unwrap().stop();
        std::thread::sleep(Duration::from_secs(1));
        self.connect();
    }
}

pub struct IncomingCommand;
impl IncomingCommand {
    pub fn execute(client: &Client, network_command: &NetworkCommands) -> BuildResult {
        match network_command {
            NetworkCommands::SystemCommand(command, args) => {
                IncomingCommand.system_command(command, args)
            }
            NetworkCommands::FileTransferStart(transfer) => client.transfers.start_new(transfer),
            NetworkCommands::FileTransferChunk(chunk) => client.transfers.append_chunk(chunk),
            NetworkCommands::FileTransferEnd(id) => client.transfers.complete(id),
            _ => Ok(()),
        }
    }

    fn system_command(&self, command: &str, args: &[String]) -> BuildResult {
        let result = Command::new(command).args(args).output();

        println!("Command result: {:#?}", result);
        match result {
            Ok(_output) => {
                // println!("  Status: {}", output.status);
                // println!("  OUT: {}", String::from_utf8_lossy(&output.stdout));
                // println!("  ERR: {}", String::from_utf8_lossy(&output.stderr));
                Ok(())
            }
            Err(e) => {
                println!("{}", format!("Failed! {e}").red());
                Err(BuildError::from(e))
            }
        }
    }
}
