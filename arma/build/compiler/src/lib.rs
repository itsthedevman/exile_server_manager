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
    target: String,
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
            target: "".into(),
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
            "windows" => "windows".into(),
            "linux" => "linux".into(),
            t => panic!(
                "Invalid target provided: {t}. Target can either be \"windows\" or \"linux\""
            ),
        };
        self
    }

    pub fn compile(&mut self) -> CompilerResult {
        assert!(!self.target.is_empty());

        self.load_files()?;
        self.apply_replacements()?;
        self.write_to_destination()?;

        Ok(())
    }

    pub fn replace<'a, F: 'static>(&'a mut self, regex_str: &'a str, callback: F) -> &'a mut Self
    where
        F: Fn(&Data, &Captures) -> Result<Option<String>, CompilerError>,
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
            .map(|f| {
                let extension = match f.path().extension() {
                    Some(e) => format!(".{}", e.to_string_lossy()),
                    None => "".into(),
                };

                File {
                    relative_path: f
                        .path()
                        .to_string_lossy()
                        .replace(&self.source.to_string_lossy().to_string(), "")[1..]
                        .to_string(),
                    file_name: f
                        .file_name()
                        .to_string_lossy()
                        .to_string()
                        .replace(&extension, ""),
                    extension,
                    content: std::fs::read_to_string(f.path()).unwrap(),
                }
            })
            .collect();

        Ok(())
    }

    fn apply_replacements(&mut self) -> CompilerResult {
        for file in self.files.iter_mut() {
            for replacement in self.replacements.iter() {
                let data = Data {
                    target: self.target.to_owned(),
                    file_name: file.file_name.to_owned(),
                    file_path: file.relative_path.to_owned(),
                    file_extension: file.extension.to_owned(),
                };

                file.replace(replacement, &data)?
            }
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
    pub extension: String,
    pub content: String,
}

impl File {
    pub fn replace(&mut self, replacement: &Replacement, data: &Data) -> CompilerResult {
        let content = self.content.to_owned();
        let captures: Vec<Captures> = replacement.regex.captures_iter(&content).collect();

        for capture in captures {
            match (replacement.callback)(data, &capture)? {
                Some(result) => {
                    self.content = self
                        .content
                        .replace(capture.get(0).unwrap().as_str(), &result);
                }
                None => {}
            };
        }

        Ok(())
    }
}

pub struct Replacement {
    pub callback: Box<dyn Fn(&Data, &Captures) -> Result<Option<String>, CompilerError>>,
    pub regex: Regex,
}

#[derive(Default)]
pub struct Data {
    pub target: String,
    pub file_path: String,
    pub file_name: String,
    pub file_extension: String,
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
                .replace(r#"compiler\.os\.path\((.+,?)\)"#, |compiler, matches| {
                    let path_chunks: Vec<String> = matches
                        .get(1)
                        .unwrap()
                        .as_str()
                        .split(',')
                        .map(|p| p.trim().replace('"', ""))
                        .collect();

                    let separator = if compiler.target == "windows" {
                        "\\"
                    } else {
                        "/"
                    };

                    // Windows: \my_addon\path
                    // Linux: /my_addon/path
                    Ok(Some(format!(
                        "\"{}{}\"",
                        separator,
                        path_chunks.join(separator)
                    )))
                })
                .compile(),
            Ok(())
        )
    }
}
