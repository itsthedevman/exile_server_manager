// Most of this code was from the example, thank you!
// https://github.com/lemunozm/message-io/tree/master/examples/file-transfer

mod builder;

use builder::Builder;
use message_io::network::{NetEvent, Transport};
use message_io::node::{self, NodeEvent};
use std::fs::{self, File};
use std::io::{Read};
use std::time::{Duration};
use serde::{Serialize, Deserialize};
use clap::{Parser, ArgEnum, Subcommand};

/// Builds ESM's Arma 3 server mod
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    #[clap(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    Run {
        /// Build the extension as 32 bit instead of 64 bit
        #[clap(short, long)]
        build_x32: bool,

        /// Set the target build platform for the extension
        #[clap(short, long, arg_enum, default_value_t = BuildOS::Windows)]
        target: BuildOS,

        /// Sets the logging level for the extension and the mod
        #[clap(short, long, arg_enum, default_value_t = LogLevel::Debug)]
        log_level: LogLevel,

        /// Sets the logging level for the extension and the mod
        #[clap(short, long, arg_enum, default_value_t = BuildEnv::Development)]
        env: BuildEnv,
    }
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
pub enum BuildOS {
    Linux,
    Windows,
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
pub enum LogLevel {
    Error,
    Warn,
    Info,
    Debug,
    Trace
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
pub enum BuildEnv {
    Development,
    Production
}

#[derive(Serialize, Deserialize)]
pub enum SenderMsg {
    //From sender to receiver
    FileRequest(String, usize), // name, size
    Chunk(Vec<u8>),             // data
}

#[derive(Serialize, Deserialize)]
pub enum ReceiverMsg {
    //From receiver to sender
    CanReceive(bool),
}

enum Signal {
    SendChunk,
    // Other signals here
}

const CHUNK_SIZE: usize = 65536;

fn main() {
    let args = Args::parse();

    let builder = match args.command {
        Commands::Run { build_x32, target, log_level, env } => {
            Builder::new(build_x32, target, log_level, env)
        }
    };

    print_info(&builder);

    // Spin up the server
    // Kill arma
}


pub fn run(file_path: String) {
    let (handler, listener) = node::split();

    let server_addr = "127.0.0.1:3005";
    let (server_id, _) = handler.network().connect(Transport::FramedTcp, server_addr).unwrap();

    let file_size = fs::metadata(&file_path).unwrap().len() as usize;
    let mut file = File::open(&file_path).unwrap();
    let file_name: String = file_path.rsplit('/').into_iter().next().unwrap_or(&file_path).into();

    let mut file_bytes_sent = 0;
    listener.for_each(move |event| match event {
        NodeEvent::Network(net_event) => match net_event {
            NetEvent::Connected(_, established) => {
                if established {
                    println!("Sender connected by TCP at {}", server_addr);
                    let request = SenderMsg::FileRequest(file_name.clone(), file_size);
                    let output_data = bincode::serialize(&request).unwrap();
                    handler.network().send(server_id, &output_data);
                }
                else {
                    println!("Can not connect to the receiver by TCP to {}", server_addr)
                }
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_, input_data) => {
                let message: ReceiverMsg = bincode::deserialize(&input_data).unwrap();
                match message {
                    ReceiverMsg::CanReceive(can) => match can {
                        true => handler.signals().send(Signal::SendChunk), // Start sending
                        false => {
                            handler.stop();
                            println!("The receiver can not receive the file :(");
                        }
                    },
                }
            }
            NetEvent::Disconnected(_) => {
                handler.stop();
                println!("\nReceiver disconnected");
            }
        },
        NodeEvent::Signal(signal) => match signal {
            Signal::SendChunk => {
                let mut data = [0; CHUNK_SIZE];
                let bytes_read = file.read(&mut data).unwrap();
                if bytes_read > 0 {
                    let chunk = SenderMsg::Chunk(Vec::from(&data[0..bytes_read]));
                    let output_data = bincode::serialize(&chunk).unwrap();
                    handler.network().send(server_id, &output_data);
                    file_bytes_sent += bytes_read;

                    let percentage = ((file_bytes_sent as f32 / file_size as f32) * 100.0) as usize;
                    print!("\rSending '{}': {}%", file_name, percentage);

                    handler.signals().send_with_timer(Signal::SendChunk, Duration::from_micros(10));
                }
                else {
                    println!("\nFile sent!");
                    handler.stop();
                }
            }
        },
    });
}


fn print_info(builder: &Builder) {
    println!(
r#"| ESM Build tool
|   OS: {:?}
|   ARCH: {:?}
|   ENV: {:?}
|   LOG_LEVEL: {:?}
|   GIT_DIRECTORY: {}
|   BUILD_DIRECTORY: {}
"#,
        builder.target, builder.arch, builder.env,
        builder.log_level, builder.git_directory, builder.build_directory
    )
}
