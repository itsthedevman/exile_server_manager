use colored::Colorize;
use lazy_static::lazy_static;
use parking_lot::RwLock;
use rand::seq::IteratorRandom;
use std::{collections::HashMap, io::Write, sync::Arc, thread, time::Duration};
use uuid::Uuid;
use vfs::{PhysicalFS, VfsPath};

use crate::{BuildResult, FileChunk, FileTransfer};

lazy_static! {
    static ref ROOT_PATH: VfsPath = VfsPath::new(PhysicalFS::new("C:"));
}

#[derive(Debug)]
pub struct IncomingTransfer {
    pub id: Uuid,
    pub size: usize,
    pub total_size: usize,
    pub finished: bool,
    pub path: VfsPath,
    pub chunks: Vec<Chunk>,
}

impl IncomingTransfer {
    pub fn combine_files(&mut self) -> BuildResult {
        let mut file = self.path.create_file()?;

        let parent_path = self.path.parent().unwrap();
        for index in 0..self.chunks.len() {
            // It cannot find the file chunk in the filesystem
            let child_file = parent_path.join(&format!("{}.{}", self.path.filename(), index))?;
            let content = child_file.read_to_string()?;
            let bytes = content.as_bytes();

            match file.write_all(bytes) {
                Ok(_) => {
                    self.size += bytes.len();
                    child_file.remove_file()?;
                }
                Err(e) => return Err(e.into()),
            };
        }

        if self.size != self.total_size {
            return Err(format!(
                "Failed to write all expected bytes. Wrote {} of {}",
                self.size, self.total_size
            )
            .into());
        }

        self.finished = true;

        Ok(())
    }

    pub fn chunks_written(&self) -> bool {
        !self.chunks.is_empty() && self.chunks.iter().all(|c| c.written)
    }
}

#[derive(Clone, Default, Debug)]
pub struct Chunk {
    pub written: bool,
}

pub struct Transfers {
    // lookup: Arc<RwLock<HashMap<Uuid, usize>>>,
    transfers: Arc<RwLock<HashMap<Uuid, IncomingTransfer>>>,
}

impl Transfers {
    pub fn new() -> Self {
        let transfer = Transfers {
            transfers: Arc::new(RwLock::new(HashMap::new())),
        };

        transfer.write();
        transfer
    }

    pub fn start_new(&self, transfer: &FileTransfer) -> BuildResult {
        println!("Starting {}", transfer.id);

        loop {
            thread::sleep(Duration::from_secs_f32(0.4));

            match self.transfers.try_read() {
                Some(r) => {
                    if r.contains_key(&transfer.id) {
                        return Err(format!(
                            "Transfer with ID {} has already been started",
                            transfer.id
                        )
                        .into());
                    }

                    break;
                }
                None => continue,
            }
        }

        println!("Adding {}", transfer.id);
        self.add(transfer)?;

        Ok(())
    }

    pub fn append_chunk(&self, incoming_chunk: &FileChunk) -> BuildResult {
        loop {
            match self.transfers.try_write() {
                Some(mut w) => match w.get_mut(&incoming_chunk.id) {
                    Some(transfer) => {
                        let mut chunk = &mut transfer.chunks[incoming_chunk.index];
                        let bytes = incoming_chunk.bytes.clone();

                        println!(
                            "Appended chunk {} for {}",
                            incoming_chunk.index, incoming_chunk.id
                        );

                        let path = transfer.path.parent().unwrap();
                        let file = path.join(&format!(
                            "{}.{}",
                            transfer.path.filename(),
                            incoming_chunk.index
                        ))?;

                        file.create_file()?.write_all(&bytes)?;

                        chunk.written = true;

                        break;
                    }
                    None => {
                        return Err(format!(
                            "Failed to find transfer for chunk {}",
                            &incoming_chunk.id
                        )
                        .into())
                    }
                },
                None => {}
            }

            thread::sleep(Duration::from_secs_f32(0.1));
        }

        println!(
            "Wrote chunk #{} for {}",
            incoming_chunk.index, incoming_chunk.id
        );

        Ok(())
    }

    pub fn complete(&self, id: &Uuid) -> BuildResult {
        println!("Waiting for completion {}", id);
        loop {
            thread::sleep(Duration::from_secs_f32(0.5));

            let reader = match self.transfers.try_read() {
                Some(r) => r,
                None => continue,
            };

            println!("Checking {id}");

            if !reader.contains_key(id) {
                break;
            }
        }

        println!("Completed {}", id);

        Ok(())
    }

    fn add(&self, transfer: &FileTransfer) -> BuildResult {
        // Any slashes in the front will cause this to fail
        let destination_path =
            ROOT_PATH.join(&transfer.destination_path.trim_start_matches('/'))?;

        // Ensure all directories exist
        destination_path.create_dir_all()?;

        let path = destination_path.join(&transfer.file_name)?;
        path.create_file()?;

        let file_transfer = IncomingTransfer {
            id: transfer.id,
            size: 0,
            total_size: transfer.total_size,
            path,
            finished: false,
            chunks: vec![Default::default(); transfer.number_of_chunks],
        };

        loop {
            match self.transfers.try_write() {
                Some(mut w) => match w.insert(transfer.id, file_transfer) {
                    Some(_) => break,
                    None => return Err(format!("Failed to add transfer {}", transfer.id).into()),
                },
                None => {}
            }

            thread::sleep(Duration::from_secs_f32(0.2));
        }

        Ok(())
    }

    fn write(&self) {
        let transfers = self.transfers.to_owned();

        thread::spawn(move || loop {
            thread::sleep(Duration::from_secs_f32(0.4));

            let reader = match transfers.try_read() {
                Some(w) => w,
                None => {
                    continue;
                }
            };

            let mut rng = rand::thread_rng();
            let transfer = match reader.values().choose(&mut rng) {
                Some(t) => t,
                None => continue,
            };

            println!(
                "Checking {} - Chunks {} - File {}",
                transfer.id,
                transfer.chunks_written(),
                transfer.finished
            );

            if !transfer.chunks_written() {
                continue;
            }

            let id = transfer.id.to_owned();
            drop(reader);
            println!("Writing {id}");

            loop {
                thread::sleep(Duration::from_secs_f32(0.2));

                let mut writer = match transfers.try_write() {
                    Some(w) => w,
                    None => continue,
                };

                println!("Write {id}");

                let mut transfer = match writer.remove(&id) {
                    Some(t) => t,
                    None => break,
                };
                drop(writer);

                println!("Combine {id}");

                match transfer.combine_files() {
                    Ok(_) => {}
                    Err(e) => {
                        println!(
                            "{} - Failed to open file {} for appending. {}",
                            "ERROR".red().bold(),
                            transfer.id,
                            e
                        );
                        continue;
                    }
                }
            }
        });
    }
}
