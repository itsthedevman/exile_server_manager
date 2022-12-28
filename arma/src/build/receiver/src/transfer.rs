use colored::Colorize;

use parking_lot::RwLock;
use rand::seq::IteratorRandom;
use sha1::{Digest, Sha1};
use std::{collections::HashMap, fs, io::Write, path::PathBuf, sync::Arc, thread};
use uuid::Uuid;

use crate::{read_lock, write_lock, BuildError, BuildResult, FileChunk, FileTransfer};

pub struct Transfers {
    transfers: Arc<RwLock<HashMap<Uuid, IncomingTransfer>>>,
}

impl Transfers {
    pub fn new() -> Self {
        let transfer = Transfers {
            transfers: Arc::new(RwLock::new(HashMap::new())),
        };

        transfer.write();
        transfer.write();
        transfer
    }

    pub fn clear(&mut self) {
        write_lock(&self.transfers, |mut writer| {
            writer.clear();
            Ok(true)
        })
        .unwrap();
    }

    pub fn start_new(&self, transfer: &FileTransfer) -> Result<bool, BuildError> {
        println!(
            "Starting transfer - {} - {} -> {}",
            transfer.id.to_string().bright_yellow(),
            transfer.file_name,
            transfer.destination_path
        );

        read_lock(&self.transfers, |reader| {
            if reader.contains_key(&transfer.id) {
                return Err(
                    format!("Transfer with ID {} has already been started", transfer.id).into(),
                );
            }

            Ok(true)
        })?;

        if !self.transfer_needed(transfer) {
            println!("Transfer not needed - {}", transfer.id);
            return Ok(false);
        }

        self.add(transfer)?;
        println!("Transfer approved - {}", transfer.id.to_string().blue());
        Ok(true)
    }

    pub fn append_chunk(&self, incoming_chunk: &FileChunk) -> BuildResult {
        write_lock(&self.transfers, |mut writer| {
            let transfer = match writer.get_mut(&incoming_chunk.id) {
                Some(transfer) => transfer,
                None => {
                    return Err(
                        format!("Failed to find transfer for chunk {}", &incoming_chunk.id).into(),
                    )
                }
            };

            let mut chunk = &mut transfer.chunks[incoming_chunk.index];
            let bytes = incoming_chunk.bytes.clone();

            let path = transfer.path.parent().unwrap();
            let file = path.join(&format!(
                "{}.{}",
                transfer.path.file_name().unwrap().to_string_lossy(),
                incoming_chunk.index
            ));

            fs::write(file, bytes)?;
            chunk.written = true;

            Ok(true)
        })?;

        Ok(())
    }

    pub fn complete(&self, id: &Uuid) -> BuildResult {
        read_lock(&self.transfers, |reader| Ok(!reader.contains_key(id)))?;

        println!("Finished transfer - {}\n", id.to_string().bright_green());

        Ok(())
    }

    fn add(&self, transfer: &FileTransfer) -> BuildResult {
        // Any slashes in the front will cause this to fail
        let destination_path = as_local_path(&transfer.destination_path)?;

        // Ensure all directories exist
        fs::create_dir_all(&destination_path)?;

        write_lock(&self.transfers, |mut writer| {
            let path = destination_path.join(&transfer.file_name);

            let file_transfer = IncomingTransfer {
                id: transfer.id,
                size: 0,
                total_size: transfer.total_size,
                path,
                finished: false,
                chunks: vec![Default::default(); transfer.number_of_chunks],
            };

            writer.insert(transfer.id, file_transfer);
            Ok(true)
        })?;

        Ok(())
    }

    fn write(&self) {
        let transfers = self.transfers.to_owned();

        thread::spawn(move || loop {
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

            if !transfer.chunks_written() {
                continue;
            }

            let id = transfer.id.to_owned();
            drop(reader);

            let result = write_lock(&transfers, |mut writer| {
                let mut transfer = match writer.remove(&id) {
                    Some(t) => t,
                    None => return Ok(true),
                };
                drop(writer);

                transfer.combine_files()?;
                Ok(true)
            });

            if let Err(e) = result {
                println!("{} - {}", "ERROR".red().bold(), e);
                continue;
            };
        });
    }

    fn transfer_needed(&self, transfer: &FileTransfer) -> bool {
        let destination_path = match as_local_path(&transfer.destination_path) {
            Ok(p) => p.join(&transfer.file_name),
            Err(_e) => return true,
        };

        if destination_path.exists() {
            return true;
        }

        let bytes = match fs::read(destination_path) {
            Ok(b) => b,
            Err(_) => return true,
        };

        let sha1 = Sha1::new().chain_update(bytes).finalize().to_vec();
        !sha1.eq(&transfer.sha1)
    }
}

fn as_local_path(path: &str) -> Result<PathBuf, BuildError> {
    Ok(crate::ROOT_PATH.join(path.trim_start_matches('/')))
}

#[derive(Debug, Clone)]
pub struct IncomingTransfer {
    pub id: Uuid,
    pub size: usize,
    pub total_size: usize,
    pub finished: bool,
    pub path: PathBuf,
    pub chunks: Vec<Chunk>,
}

impl IncomingTransfer {
    pub fn combine_files(&mut self) -> BuildResult {
        let mut file = std::fs::File::create(&self.path).unwrap();

        let parent_path = self.path.parent().unwrap();
        for index in 0..self.chunks.len() {
            let child_file = parent_path.join(&format!(
                "{}.{}",
                self.path.file_name().unwrap().to_string_lossy(),
                index
            ));

            let buffer = fs::read(&child_file).unwrap();

            match file.write_all(&buffer) {
                Ok(_) => {
                    self.size += buffer.len();
                    fs::remove_file(&child_file)?;
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
