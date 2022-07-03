use colored::Colorize;
use message_io::network::{Endpoint, NetEvent, Transport};
use message_io::node::{self, NodeHandler, NodeTask};
use parking_lot::RwLock;
use uuid::Uuid;

use crate::{read_lock, write_lock, BuildResult, Command, NetworkCommand};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

#[derive(Clone)]
pub struct Server {
    pub connected: Arc<AtomicBool>,
    pub requests: Arc<RwLock<HashMap<Uuid, ()>>>,
    server_task: Arc<Option<NodeTask>>,
    handler: Option<NodeHandler<()>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
}

impl Server {
    pub fn new() -> Self {
        Server {
            connected: Arc::new(AtomicBool::new(false)),
            server_task: Arc::new(None),
            handler: None,
            endpoint: Arc::new(RwLock::new(None)),
            requests: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn start(&mut self) -> BuildResult {
        let (handler, listener) = node::split::<()>();

        let listen_addr = "0.0.0.0:6969";
        if let Err(e) = handler.network().listen(Transport::FramedTcp, listen_addr) {
            return Err(e.to_string().into());
        }

        let server = self.clone();
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(_, _) => unreachable!(),
            NetEvent::Accepted(_endpoint, _id) => {}
            NetEvent::Message(endpoint, input_data) => {
                let message: NetworkCommand = serde_json::from_slice(input_data).unwrap();
                match message.command {
                    Command::Hello => {
                        *server.endpoint.write() = Some(endpoint);
                        server.connected.store(true, Ordering::SeqCst);
                    }
                    Command::Error(e) => {
                        println!("{}", "failed".red().bold());
                        println!(
                            "{} - {} - {}",
                            "<esm_bt>".blue().bold(),
                            "error".red().bold(),
                            e
                        );
                        std::process::exit(1)
                    }
                    _ => {}
                }

                write_lock(
                    &server.requests,
                    Duration::from_secs_f32(0.001),
                    |mut writer| {
                        writer.remove(&message.id);
                        Ok(true)
                    },
                )
                .unwrap();
            }
            NetEvent::Disconnected(_endpoint) => {}
        });

        self.server_task = Arc::new(Some(task));
        self.handler = Some(handler);
        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(s) = self.handler.as_ref() {
            s.stop()
        }
    }

    pub fn send(&mut self, command: Command) -> BuildResult {
        let command = NetworkCommand::new(command);

        let data = serde_json::to_vec(&command).unwrap();

        self.track_request(&command.id)?;

        self.handler
            .as_ref()
            .unwrap()
            .network()
            .send(self.endpoint.read().unwrap(), data.as_slice());

        self.wait_for_response(&command.id)
    }

    fn track_request(&mut self, id: &Uuid) -> BuildResult {
        write_lock(
            &self.requests,
            Duration::from_secs_f32(0.005),
            |mut writer| {
                writer.insert(id.to_owned(), ());
                Ok(true)
            },
        )
    }

    fn wait_for_response(&mut self, id: &Uuid) -> BuildResult {
        read_lock(&self.requests, Duration::from_secs_f32(0.005), |reader| {
            Ok(!reader.contains_key(id))
        })
    }
}
