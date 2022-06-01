use std::net::ToSocketAddrs;
use std::process::Command;
use std::time::Duration;

use message_io::network::{NetEvent, Transport, Endpoint};
use message_io::node::{self, NodeHandler};
use serde::{Serialize, Deserialize};

#[derive(Clone)]
pub struct Client {
    handler: Option<NodeHandler<()>>,
    endpoint: Option<Endpoint>,
}

impl Client {
    pub fn new() -> Self {
        let mut client = Client {
            handler: None,
            endpoint: None
        };

        client.connect();
        client
    }

    fn connect(&mut self) {
        let (handler, listener) = node::split::<()>();

        // Move this to an argument that is passed into the program
        let server_addr = "0.0.0.0:6969".to_socket_addrs().unwrap().next().unwrap();
        let (server, _) = handler.network().connect(Transport::FramedTcp, server_addr).unwrap();

        self.handler = Some(handler);
        self.endpoint = Some(server);

        let mut client = self.clone();
        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_endpoint, established) => {
                if established {
                    println!("Connected to build host @ {}", server_addr);
                    self.send(NetworkCommands::Hello);
                }
                else {
                    println!("Failed to connect to build host @ {}", server_addr);
                    client.on_disconnect();
                }
            },
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_endpoint, input_data) => {
                let message: NetworkCommands = bincode::deserialize(input_data).unwrap();
                message.execute();
            }
            NetEvent::Disconnected(_endpoint) => {
                client.on_disconnect();
            }
        });
    }

    fn send(&self, command: NetworkCommands) {
        let data = bincode::serialize(&command).unwrap();
        self.handler.as_ref().unwrap().network().send(self.endpoint.unwrap(), &data);
    }

    fn on_disconnect(&mut self) {
        self.handler.as_ref().unwrap().stop();
        std::thread::sleep(Duration::from_secs(1));
        self.connect();
    }
}

impl Default for Client {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Serialize, Deserialize)]
enum NetworkCommands {
    Hello,
    SystemCommand(String, Vec<String>)
}

impl NetworkCommands {
    pub fn execute(&self) {
        match self {
            NetworkCommands::Hello => (),
            NetworkCommands::SystemCommand(command, args) => self.system_command(command, args),
        }
    }

    fn system_command(&self, command: &str, args: &[String]) {
        Command::new(command)
                .args(args)
                .output()
                .expect("failed to execute process");
    }
}
