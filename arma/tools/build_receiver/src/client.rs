use std::net::ToSocketAddrs;
use std::process::Command as SystemCommand;
use std::sync::Arc;
use std::time::Duration;

use crate::{transfer::*, BuildError, BuildResult, Command, NetworkCommand};
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
                    let message = NetworkCommand::new(Command::Hello);
                    client.send(message);
                } else {
                    println!("Failed to connect to build host @ {}", server_addr);
                    client.on_disconnect();
                }
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_endpoint, input_data) => {
                println!("VEC: {:?}", input_data);
                println!("STRING: {:?}", String::from_utf8_lossy(input_data));
                let mut message: NetworkCommand = match serde_json::from_slice(input_data) {
                    Ok(c) => c,
                    Err(e) => {
                        let message = NetworkCommand::new(Command::Error(e.to_string()));
                        client.send(message);
                        return;
                    }
                };

                // println!("Inbound message:\n{:?}", message);
                match IncomingCommand::execute(&client, &message.command) {
                    Ok(_) => {
                        message.command = Command::Success;
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
        std::thread::sleep(Duration::from_secs(1));
        self.connect();
    }
}

pub struct IncomingCommand;
impl IncomingCommand {
    pub fn execute(client: &Client, network_command: &Command) -> BuildResult {
        match network_command {
            Command::System(command, args) => IncomingCommand.system_command(command, args),
            Command::FileTransferStart(transfer) => client.transfers.start_new(transfer),
            Command::FileTransferChunk(chunk) => client.transfers.append_chunk(chunk),
            Command::FileTransferEnd(id) => client.transfers.complete(id),
            _ => Ok(()),
        }
    }

    fn system_command(&self, command: &str, args: &[String]) -> BuildResult {
        let result = SystemCommand::new(command).args(args).output();

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
