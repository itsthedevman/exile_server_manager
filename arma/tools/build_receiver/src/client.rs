use std::net::ToSocketAddrs;
use std::process::Command;
use std::sync::Arc;
use std::time::Duration;

use colored::Colorize;
use message_io::network::{NetEvent, Transport, Endpoint};
use message_io::node::{self, NodeHandler, NodeTask};
use serde::{Serialize, Deserialize};

#[derive(Clone)]
pub struct Client {
    handler: Option<NodeHandler<()>>,
    endpoint: Option<Endpoint>,
    task: Arc<Option<NodeTask>>,
    pub host: String
}

impl Client {
    pub fn new(host: String) -> Self {
        Client {
            handler: None,
            endpoint: None,
            task: Arc::new(None),
            host
        }
    }

    pub fn connect(&mut self) {
        let (handler, listener) = node::split::<()>();

        // Move this to an argument that is passed into the program
        let server_addr = self.host.to_socket_addrs().unwrap().next().unwrap();
        let (server, _) = handler.network().connect(Transport::FramedTcp, server_addr).unwrap();

        self.handler = Some(handler);
        self.endpoint = Some(server);

        let mut client = self.clone();
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(_endpoint, established) => {
                if established {
                    println!("Connected to build host @ {}", server_addr);
                    client.send(NetworkCommands::Hello);
                }
                else {
                    println!("Failed to connect to build host @ {}", server_addr);
                    client.on_disconnect();
                }
            },
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_endpoint, input_data) => {
                let message: NetworkCommands = bincode::deserialize(input_data).unwrap();
                match message.execute() {
                    Ok(_) => {
                        client.send(NetworkCommands::Success);
                    },
                    Err(e) => {
                        client.send(NetworkCommands::Error(e));
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
        let data = bincode::serialize(&command).unwrap();
        self.handler.as_ref().unwrap().network().send(self.endpoint.unwrap(), &data);
    }

    fn on_disconnect(&mut self) {
        self.handler.as_ref().unwrap().stop();
        std::thread::sleep(Duration::from_secs(1));
        self.connect();
    }
}

#[derive(Serialize, Deserialize)]
enum NetworkCommands {
    Hello,
    Success,
    Error(String),
    SystemCommand(String, Vec<String>),
}


impl NetworkCommands {
    pub fn execute(&self) -> Result<(), String> {
        match self {
            NetworkCommands::SystemCommand(command, args) => self.system_command(command, args),
            _ => Ok(()),
        }
    }

    fn system_command(&self, command: &str, args: &[String]) -> Result<(), String> {
        println!("Running system command `{command} {}`", args.join(" "));

        let result = Command::new(command)
                .args(args)
                .output();

        match result {
            Ok(output) => {
                println!("  Status: {}", output.status);
                println!("  OUT: {}", String::from_utf8_lossy(&output.stdout));
                println!("  ERR: {}", String::from_utf8_lossy(&output.stderr));
                Ok(())
            },
            Err(e) => {
                println!("{}", format!("Failed! {e}").red());
                Err(e.to_string())
            }
        }
    }
}
