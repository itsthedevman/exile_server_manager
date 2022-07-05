use colored::Colorize;
use lazy_static::lazy_static;
use parking_lot::RwLock;
use rand::seq::IteratorRandom;
use std::{collections::HashMap, io::Write, sync::Arc, thread, time::Duration};
use uuid::Uuid;
use vfs::{PhysicalFS, VfsPath};

use crate::{read_lock, write_lock, BuildResult, FileChunk, FileTransfer};

lazy_static! {
    static ref ROOT_PATH: VfsPath = VfsPath::new(PhysicalFS::new("C:"));
}

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

    pub fn start_new(&self, transfer: &FileTransfer) -> BuildResult {
        println!(
            "Starting transfer - {} - {} -> {}",
            transfer.id.to_string().bright_yellow(),
            transfer.file_name.black(),
            transfer.destination_path.black()
        );

        read_lock(&self.transfers, |reader| {
            if reader.contains_key(&transfer.id) {
                return Err(
                    format!("Transfer with ID {} has already been started", transfer.id).into(),
                );
            }

            Ok(true)
        })?;

        self.add(transfer)?;

        Ok(())
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
                transfer.path.filename(),
                incoming_chunk.index
            ))?;

            file.create_file()?.write_all(&bytes)?;

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
        let destination_path =
            &ROOT_PATH.join(&transfer.destination_path.trim_start_matches('/'))?;

        // Ensure all directories exist
        destination_path.create_dir_all()?;

        write_lock(&self.transfers, |mut writer| {
            let path = destination_path.join(&transfer.file_name).unwrap();

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
}

#[derive(Debug, Clone)]
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
            let child_file = parent_path.join(&format!("{}.{}", self.path.filename(), index))?;

            let mut buffer = Vec::new();
            child_file.open_file()?.read_to_end(&mut buffer)?;

            match file.write_all(&buffer) {
                Ok(_) => {
                    self.size += buffer.len();
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
