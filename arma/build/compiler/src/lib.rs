// Create a struct that acts as the entry point for this lib
// This struct is a builder. Allowing for source, destination, and defining replacements.
// The replacement method takes in regex and a closure. The closure is given a reference to the compiler itself, plus any other data needed

mod error;
use std::path::PathBuf;

pub use error::CompilerError;

use regex::{Captures, Regex};
use walkdir::WalkDir;

pub type CompilerResult = Result<(), CompilerError>;

pub struct Compiler {
    files: Vec<File>,
    replacements: Vec<Replacement>,
    source: PathBuf,
    destination: PathBuf,
    target: Target,
}

impl Default for Compiler {
    fn default() -> Self {
        Self::new()
    }
}

impl Compiler {
    pub fn new() -> Self {
        Compiler {
            files: vec![],
            replacements: vec![],
            source: "".into(),
            destination: "".into(),
            target: Target::None,
        }
    }

    pub fn source(&mut self, path: &str) -> &mut Self {
        self.source = PathBuf::from(path);
        self
    }

    pub fn destination(&mut self, path: &str) -> &mut Self {
        self.destination = PathBuf::from(path);
        self
    }

    pub fn target(&mut self, target: &str) -> &mut Self {
        self.target = match target {
            "windows" => Target::Windows,
            "linux" => Target::Linux,
            t => panic!(
                "Invalid target provided: {t}. Target can either be \"windows\" or \"linux\""
            ),
        };
        self
    }

    pub fn compile(&mut self) -> CompilerResult {
        assert_ne!(self.target, Target::None);

        self.load_files()?;
        self.apply_replacements()?;
        self.write_to_destination()?;

        Ok(())
    }

    pub fn replace<'a, F: 'static>(&'a mut self, regex_str: &'a str, callback: F) -> &'a mut Self
    where
        F: Fn(&Data, &Captures) -> Option<String>,
    {
        let regex = Regex::new(regex_str).unwrap();
        self.replacements.push(Replacement {
            callback: Box::new(callback),
            regex,
        });
        self
    }

    fn load_files(&mut self) -> CompilerResult {
        let source_path = WalkDir::new(&self.source);
        self.files = source_path
            .into_iter()
            .filter_map(|f| f.ok())
            .filter(|f| f.file_type().is_file())
            .map(|f| File {
                relative_path: f
                    .path()
                    .to_string_lossy()
                    .replace(&self.source.to_string_lossy().to_string(), "")[1..]
                    .to_string(),
                file_name: f.file_name().to_string_lossy().to_string(),
                content: std::fs::read_to_string(f.path()).unwrap(),
            })
            .collect();

        Ok(())
    }

    fn apply_replacements(&mut self) -> CompilerResult {
        let data = Data {
            target: self.target.to_owned(),
        };

        for file in self.files.iter_mut() {
            self.replacements
                .iter()
                .for_each(|replacement| file.replace(replacement, &data));
        }

        Ok(())
    }

    fn write_to_destination(&mut self) -> CompilerResult {
        for file in &self.files {
            let destination_path = self.destination.join(&file.relative_path);

            std::fs::create_dir_all(&destination_path.parent().unwrap())?;
            std::fs::write(destination_path, &file.content)?;
        }

        Ok(())
    }
}

#[derive(Debug, PartialEq)]
pub struct File {
    pub relative_path: String,
    pub file_name: String,
    pub content: String,
}

impl File {
    pub fn replace(&mut self, replacement: &Replacement, data: &Data) {
        let content = self.content.to_owned();
        let captures: Vec<Captures> = replacement.regex.captures_iter(&content).collect();

        for capture in captures {
            match (replacement.callback)(data, &capture) {
                Some(result) => {
                    self.content = self
                        .content
                        .replace(capture.get(0).unwrap().as_str(), &result);
                }
                None => {}
            }
        }
    }
}

pub struct Replacement {
    pub callback: Box<dyn Fn(&Data, &Captures) -> Option<String>>,
    pub regex: Regex,
}

pub struct Data {
    pub target: Target,
}

#[derive(Debug, PartialEq, Clone)]
pub enum Target {
    None,
    Windows,
    Linux,
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
                .target("windows")
                .replace(r#"arma\.os\.path\((.+,?)\)"#, |compiler, matches| {
                    let path_chunks: Vec<String> = matches
                        .get(1)
                        .unwrap()
                        .as_str()
                        .split(',')
                        .map(|p| p.trim().replace('"', ""))
                        .collect();

                    let separator = if let Target::Windows = compiler.target {
                        "\\"
                    } else {
                        "/"
                    };

                    // Windows: \my_addon\path
                    // Linux: /my_addon/path
                    Some(format!("\"{}{}\"", separator, path_chunks.join(separator)))
                })
                .compile(),
            Ok(())
        )
    }
}
