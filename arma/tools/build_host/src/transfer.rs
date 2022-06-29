use std::{thread, time::Duration};

use crate::{server::Server, BuildResult, Command, FileChunk, FileTransfer};
use uuid::Uuid;
use vfs::{SeekAndRead, VfsPath};

const CHUNK_SIZE: usize = 65536;

pub struct Transfer;

impl Transfer {
    pub fn file(
        server: &mut Server,
        source_path: VfsPath,
        destination_path: VfsPath,
        file_name: String,
    ) -> BuildResult {
        let total_size = source_path.metadata()?.len as usize;

        let id = Uuid::new_v4();
        let transfer = FileTransfer {
            id,
            file_name,
            destination_path: destination_path.as_str()[1..].to_string(),
            number_of_chunks: if total_size < CHUNK_SIZE {
                1
            } else {
                total_size / CHUNK_SIZE
            },
            total_size,
        };

        server.send(Command::FileTransferStart(transfer));

        let mut file = source_path.open_file()?;
        let mut index = 0;
        while let Some(bytes) = chunk_file(&mut file) {
            let chunk = Command::FileTransferChunk(FileChunk {
                id,
                index,
                size: bytes.len(),
                bytes,
            });

            server.send(chunk);

            index += 1;
            thread::sleep(Duration::from_secs_f32(0.1));
        }

        server.send(Command::FileTransferEnd(id));

        Ok(())
    }

    pub fn directory(
        server: &mut Server,
        source_path: VfsPath,
        destination_path: VfsPath,
    ) -> BuildResult {
        let file_paths: Vec<VfsPath> = source_path
            .walk_dir()?
            .filter(|p| match p {
                Ok(p) => p.is_file().unwrap(),
                Err(_e) => false,
            })
            .map(|p| p.unwrap())
            .collect();

        let mut handles = Vec::new();
        for paths in file_paths.chunks(2) {
            for path in paths.iter().cloned() {
                let parent_path = source_path.parent().unwrap().as_str().to_owned();
                let mut server = server.to_owned();
                let destination_path = destination_path.clone();

                let handler = thread::spawn(move || {
                    let relative_path = path.as_str().replace(&parent_path, "");
                    let file_name = path.filename();

                    Transfer::file(
                        &mut server,
                        path,
                        destination_path
                            .join(&relative_path[1..])
                            .unwrap()
                            .parent()
                            .unwrap(),
                        file_name,
                    )
                    .unwrap();
                });
                handles.push(handler);
            }
        }

        for handle in handles {
            handle.join().unwrap();
        }

        Ok(())
    }
}

fn chunk_file(file: &mut Box<dyn SeekAndRead>) -> Option<Vec<u8>> {
    let mut data = [0; CHUNK_SIZE];

    let bytes_read = file.read(&mut data).unwrap();
    if bytes_read == 0 {
        return None;
    }

    Some(Vec::from(&data[0..bytes_read]))
}
