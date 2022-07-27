// Create a struct that acts as the entry point for this lib
// This struct is a builder. Allowing for source, destination, and defining replacements.
// The replacement method takes in regex and a closure. The closure is given a reference to the compiler itself, plus any other data needed

use std::io::Error;
use walkdir::WalkDir;

pub struct Compiler {
    files: Vec<File>,
    source: String,
    destination: String,
}

impl Default for Compiler {
    fn default() -> Self {
        Self::new()
    }
}

impl Compiler {
    pub fn new() -> Self {
        Compiler {
            files: Vec::new(),
            source: "".into(),
            destination: "".into(),
        }
    }

    pub fn source(&mut self, path: &str) -> &mut Self {
        self.source = path.to_string();
        self
    }

    pub fn destination(&mut self, path: &str) -> &mut Self {
        self.destination = path.to_string();
        self
    }

    pub fn compile(&mut self) -> Result<(), ()> {
        self.files = self.load_files().unwrap();

        println!("Files: {:#?}", self.files);
        Ok(())
    }

    fn load_files(&self) -> Result<Vec<File>, Error> {
        let source_path = WalkDir::new(&self.source);
        Ok(source_path
            .into_iter()
            .filter_map(|f| f.ok())
            .filter(|f| f.file_type().is_file())
            .map(|f| File {
                path: f.path().to_string_lossy().to_string(),
                file_name: f.file_name().to_string_lossy().to_string(),
                content: std::fs::read_to_string(f.path()).unwrap(),
            })
            .collect())
    }
}

#[derive(Debug)]
struct File {
    pub path: String,
    pub file_name: String,
    pub content: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_compiles() {
        assert_eq!(
            Compiler::new()
                .source("/home/ubuntu/esm_arma/@esm/addons")
                .destination("/home/ubuntu/esm_arma/target/@esm/addons")
                .compile(),
            Ok(())
        )
    }
}
