use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use std::io::{self, Write};

use super::{BuildOS, BuildEnv, LogLevel, BuildArch};

use message_io::network::{NetEvent, Transport, Endpoint};
use message_io::node::{self, NodeTask, NodeHandler};
use serde::{Serialize, Deserialize};
use colored::*;
use lazy_static::lazy_static;
use parking_lot::RwLock;

pub struct Builder {
    os: BuildOS,
    arch: BuildArch,
    env: BuildEnv,
    log_level: LogLevel,
    git_directory: String,
    build_directory: String,
    server: Server,
}

impl Builder {
    pub fn new(build_x32: bool, os: BuildOS,  log_level: LogLevel, env: BuildEnv) -> Self {
        let git_directory = match std::env::current_dir() {
            Ok(d) => d.to_string_lossy().to_string(),
            Err(e) => panic!("{e}")
        };

        let build_directory = format!("{}/target/@esm", git_directory);

        Builder {
            os,
            arch: if build_x32 { BuildArch::X32 } else { BuildArch::X64 },
            env,
            log_level,
            git_directory,
            build_directory,
            server: Server::new()
        }
    }

    fn print_status<F>(&mut self, message: impl Into<String> + std::fmt::Display, code: F)
    where
        F: Fn(&mut Builder)
    {
        print!("{} - {message} ... ", "<esm_bt>".blue().bold());
        io::stdout().flush().expect("Failed to flush stdout");
        code(self);
        println!("{}", "done".green().bold());
    }

    pub fn start(&mut self) {
        self.print_info();
        self.print_status("Starting build server", Builder::start_server);
        self.print_status("Waiting for receiver", Builder::wait_for_receiver);
        self.print_status("Killing Arma", Builder::kill_arma);
    }

    fn send_to_receiver(&self, command: NetworkCommands) {
        self.server.send(command);
    }

    fn print_info(&self) {
        println!(
            "{}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {}\n  {:17}: {}\n",
            "ESM Build tool".blue().bold(),
            "OS".black().bold(), self.os,
            "ARCH".black().bold(), self.arch,
            "ENV".black().bold(), self.env,
            "LOG LEVEL".black().bold(), self.log_level,
            "GIT DIRECTORY".black().bold(), self.git_directory,
            "BUILD DIRECTORY".black().bold(), self.build_directory
        )
    }

    fn start_server(&mut self) {
        self.server.start();
    }

    fn wait_for_receiver(&mut self) {
        while !self.server.connected.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_secs(1))
        }
    }

    fn kill_arma(&mut self) {
        lazy_static! {
            static ref WINDOWS_EXES: Vec<&'static str> = vec![
                "arma3server.exe", "arma3server_x64.exe",
                "arma3_x64.exe", "arma3.exe", "arma3battleye.exe"
            ];

            static ref LINUX_EXES: Vec<&'static str> = vec!["arma3server", "arma3server_x64"];
        };

        match self.os {
            BuildOS::Windows => {
                for exe in WINDOWS_EXES.iter() {
                    let command = format!("taskkill /IM \"{}\" /F /T >nul 2>&1", exe);
                    let args: Vec<String> = ["/IM", exe, "/F", "/T", ">nul", "2>&1"].iter().map(|a| a.to_string()).collect();
                    self.send_to_receiver(NetworkCommands::SystemCommand(command, args));
                }
            },
            BuildOS::Linux => todo!(),
        }
    }

}

#[derive(Clone)]
struct Server {
    pub connected: Arc<AtomicBool>,
    server_task: Arc<Option<NodeTask>>,
    handler: Option<NodeHandler<()>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
}

impl Server {
    pub fn new() -> Self {
        Server { connected: Arc::new(AtomicBool::new(false)), server_task: Arc::new(None), handler: None, endpoint: Arc::new(RwLock::new(None)) }
    }

    pub fn start(&mut self) {
        let (handler, listener) = node::split::<()>();

        let listen_addr = "0.0.0.0:6969";
        handler.network().listen(Transport::FramedTcp, listen_addr).unwrap();

        let builder = self.clone();
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(_, _) => unreachable!(),
            NetEvent::Accepted(_endpoint, _id) => { },
            NetEvent::Message(endpoint, input_data) => {
                let message: NetworkCommands = bincode::deserialize(input_data).unwrap();
                if let NetworkCommands::Hello = message {
                    *builder.endpoint.write() = Some(endpoint);
                    builder.connected.store(true, Ordering::SeqCst);
                }
            }
            NetEvent::Disconnected(_endpoint) => {}
        });

        self.server_task = Arc::new(Some(task));
        self.handler = Some(handler);
    }

    pub fn send(&self, command: NetworkCommands) {
        let data = bincode::serialize(&command).unwrap();
        self.handler.as_ref().unwrap().network().send(self.endpoint.read().unwrap(), &data);
    }
}

#[derive(Serialize, Deserialize)]
enum NetworkCommands {
    Hello,
    SystemCommand(String, Vec<String>)
}
