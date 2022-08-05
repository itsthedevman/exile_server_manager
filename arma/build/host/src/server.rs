use colored::Colorize;
use common::read_lock;
use message_io::network::{Endpoint, NetEvent, Transport};
use message_io::node::{self, NodeHandler, NodeTask};
use parking_lot::RwLock;
use uuid::Uuid;

use crate::{write_lock, BuildError, BuildResult, Command, NetworkCommand};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

#[derive(Clone)]
pub struct Server {
    pub connected: Arc<AtomicBool>,
    pub requests: Arc<RwLock<HashMap<Uuid, Result<Command, BuildError>>>>,
    server_task: Arc<Option<NodeTask>>,
    handler: Option<NodeHandler<()>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
}

impl Default for Server {
    fn default() -> Self {
        Server {
            connected: Arc::new(AtomicBool::new(false)),
            server_task: Arc::new(None),
            handler: None,
            endpoint: Arc::new(RwLock::new(None)),
            requests: Arc::new(RwLock::new(HashMap::new())),
        }
    }
}

impl Server {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn start(&mut self) -> BuildResult {
        let (handler, listener) = node::split::<()>();

        let listen_addr = "0.0.0.0:54321";
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
                    Command::Error(e) => write_lock(&server.requests, |mut writer| {
                        writer.insert(message.id, Err(e.to_owned().into()));
                        Ok(true)
                    })
                    .unwrap(),
                    c => write_lock(&server.requests, |mut writer| {
                        writer.insert(message.id, Ok(c.to_owned()));
                        Ok(true)
                    })
                    .unwrap(),
                }
            }
            NetEvent::Disconnected(_endpoint) => {
                println!("{}", "failed".red().bold());
                println!(
                    "{} - {}",
                    "<esm_bt>".blue().bold(),
                    "Build receiver has disconnected".red().bold()
                );
                std::process::exit(1);
            }
        });

        self.server_task = Arc::new(Some(task));
        self.handler = Some(handler);
        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(s) = self.handler.as_ref() {
            if self.endpoint.read().is_some() {
                let command = NetworkCommand::new(Command::KillArma);
                let data = serde_json::to_vec(&command).unwrap();

                s.network()
                    .send(self.endpoint.read().unwrap(), data.as_slice());
            };

            s.stop();
        }
    }

    pub fn send(&mut self, command: Command) -> Result<Command, BuildError> {
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
        write_lock(&self.requests, |mut writer| {
            writer.insert(id.to_owned(), Ok(Command::Hello));
            Ok(true)
        })
    }

    fn wait_for_response(&mut self, id: &Uuid) -> Result<Command, BuildError> {
        let result: RwLock<Result<Command, BuildError>> = RwLock::new(Ok(Command::Hello));
        read_lock(&self.requests, |reader| {
            if crate::CTRL_C_RECEIVED.load(Ordering::SeqCst) {
                return Err("Stopped by user".to_string().into());
            }

            match reader.get(id) {
                Some(v) => match v {
                    Ok(c) => {
                        if let Command::Hello = c {
                            return Ok(false);
                        }

                        *result.write() = Ok(c.to_owned());
                        Ok(true)
                    }
                    Err(e) => {
                        *result.write() = Err(e.to_string().into());
                        Ok(true)
                    }
                },
                None => Ok(false),
            }
        })?;

        let writer = result.read();
        match &*writer {
            Ok(c) => Ok(c.to_owned()),
            Err(e) => Err(e.to_string().into()),
        }
    }
}
