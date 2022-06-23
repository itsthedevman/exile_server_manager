use colored::Colorize;
use lazy_static::lazy_static;
use parking_lot::RwLock;
use std::{
    collections::HashMap,
    io::{BufWriter, Write},
    sync::Arc,
    thread,
    time::Duration,
};
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
    pub path: VfsPath,
    pub chunks: Vec<Chunk>,
}

impl IncomingTransfer {
    pub fn write_writable_chunks<T: Write>(&mut self, buffer: &mut BufWriter<T>) -> Option<usize> {
        let mut total_bytes_written = 0_usize;

        for chunk in &mut self.chunks {
            if chunk.written {
                continue;
            }

            if !chunk.ready_for_writing() {
                break;
            }

            let bytes = chunk.bytes.take().unwrap();

            match buffer.write(&bytes) {
                Ok(b) => {
                    println!("Wrote correct size: {}", b == bytes.len());
                    total_bytes_written += b;
                    chunk.written = true;
                }
                Err(e) => {
                    println!("{} - Failed to write to file. {}", "ERROR".red().bold(), e);
                    return None;
                }
            };
        }

        Some(total_bytes_written)
    }

    pub fn written(&self) -> bool {
        !self.chunks.is_empty() && self.chunks.iter().all(|c| c.written)
    }
}

#[derive(Clone, Default, Debug)]
pub struct Chunk {
    pub written: bool,
    pub bytes: Option<Vec<u8>>,
}

impl Chunk {
    pub fn ready_for_writing(&self) -> bool {
        self.bytes.is_some() && !self.written
    }
}

pub struct Transfers {
    lookup: Arc<RwLock<HashMap<Uuid, usize>>>,
    transfers: Arc<RwLock<Vec<IncomingTransfer>>>,
}

impl Transfers {
    pub fn new() -> Self {
        let transfer = Transfers {
            lookup: Arc::new(RwLock::new(HashMap::new())),
            transfers: Arc::new(RwLock::new(Vec::new())),
        };

        transfer.write();
        transfer
    }

    pub fn start_new(&self, transfer: &FileTransfer) -> BuildResult {
        println!("Starting transfer");

        if self.lookup.read().contains_key(&transfer.id) {
            return Err(
                format!("Transfer with ID {} has already been started", transfer.id).into(),
            );
        }

        self.add(transfer)?;

        Ok(())
    }

    pub fn append_chunk(&self, incoming_chunk: &FileChunk) -> BuildResult {
        println!(
            "Appending chunk {} for {}",
            incoming_chunk.index, incoming_chunk.id
        );
        match self.lookup.read().get(&incoming_chunk.id) {
            Some(i) => match self.transfers.write().get_mut(*i) {
                Some(transfer) => {
                    let mut chunk = &mut transfer.chunks[incoming_chunk.index];
                    let bytes = incoming_chunk.bytes.clone();

                    println!(
                        "Appended chunk {} for {}",
                        incoming_chunk.index, incoming_chunk.id
                    );
                    chunk.bytes = Some(bytes);
                }
                None => {
                    return Err(
                        format!("Failed to find transfer for chunk {}", &incoming_chunk.id).into(),
                    )
                }
            },
            None => {
                return Err(
                    format!("Failed to find transfer for chunk {}", &incoming_chunk.id).into(),
                )
            }
        }

        Ok(())
    }

    pub fn complete(&self, id: &Uuid) -> BuildResult {
        let index = match self.lookup.read().get(id) {
            Some(i) => i.to_owned(),
            None => return Err(format!("File transfer {} has already been completed", id).into()),
        };

        println!("Waiting for completion {}", id);
        loop {
            match self.transfers.try_read() {
                Some(r) => match r.get(index) {
                    Some(t) => {
                        if t.written() {
                            break;
                        }
                    }
                    None => {}
                },
                None => {}
            }

            println!("Sleeping");
            thread::sleep(Duration::from_secs_f32(1.0));
        }

        println!("Done waiting {}", id);
        let index = match self.lookup.write().remove(id) {
            Some(i) => i,
            None => {
                return Err(format!("File {} has already been removed", id,).into());
            }
        };

        println!("Finalizing {}", id);
        let transfer = self.transfers.write().remove(index);

        if transfer.size != transfer.total_size {
            return Err(format!(
                "File {} failed to transfer. Wrote {} of {}",
                id, transfer.size, transfer.total_size
            )
            .into());
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
            chunks: vec![Default::default(); transfer.number_of_chunks],
        };

        let mut transfers = self.transfers.write();
        transfers.push(file_transfer);

        let insert_index = transfers.len().saturating_sub(1);
        drop(transfers);

        self.lookup.write().insert(transfer.id, insert_index);

        Ok(())
    }

    fn write(&self) {
        let transfers = self.transfers.to_owned();

        thread::spawn(move || {
            let mut index = 0;

            loop {
                thread::sleep(Duration::from_secs_f32(0.5));

                println!("Checking");
                let mut writer = match transfers.try_write() {
                    Some(w) => w,
                    None => continue,
                };

                if index > writer.len().saturating_sub(1) {
                    index = 0;
                }

                let transfer = match writer.get_mut(index) {
                    Some(t) => t,
                    None => {
                        thread::sleep(Duration::from_secs_f32(0.5));
                        continue;
                    }
                };

                println!(
                    "Found transfer {}. Written {} of {}. Finished: {}",
                    transfer.path.as_str(),
                    transfer.size,
                    transfer.total_size,
                    transfer.written()
                );
                // println!("{:#?}", transfer);

                if transfer.written() {
                    continue;
                }

                match transfer.path.append_file() {
                    Ok(f) => {
                        println!("Appending");
                        let mut buffer = BufWriter::new(f);
                        match transfer.write_writable_chunks(&mut buffer) {
                            Some(bytes) => {
                                transfer.size += bytes;
                            }
                            None => {}
                        };
                    }
                    Err(e) => {
                        println!(
                            "{} - Failed to open file {} for appending. {}",
                            "ERROR".red().bold(),
                            transfer.path.as_str(),
                            e
                        );
                        continue;
                    }
                }

                drop(writer);
                index += 1;
            }
        });
    }
}
