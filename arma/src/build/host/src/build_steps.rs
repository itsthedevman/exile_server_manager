use crate::{
    builder::{local_command, Builder, git_sha_short},
    database::Database,
    BuildOS, Directory, System, BuildArch, BuildEnv,
};

use colored::*;
use common::{BuildResult, Command, write_lock};
use compiler::Compiler;
use lazy_static::lazy_static;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{fs, thread, time::Duration, path::Path};

/// Used with the test suite, this key holds the server's current esm.key
const REDIS_SERVER_KEY: &str = "test_server_key";

const ADDONS: &[&str] = &[
    "exile_server_manager",
    "exile_server_overwrites",
    "exile_server_xm8",
    "exile_server_hacking",
    "exile_server_grinding",
    "exile_server_charge_plant_started",
    "exile_server_flag_steal_started",
    "exile_server_player_connected",
];

pub fn kill_arma(builder: &mut Builder) -> BuildResult {
    match builder.os {
        BuildOS::Linux => {
            local_command("docker kill", vec!["arma-server"])?;
        }
        BuildOS::Windows => {
            builder.send_to_receiver(Command::KillArma)?;
        }
    };

    Ok(())
}

pub fn prepare_directories(builder: &mut Builder) -> BuildResult {
    ////////////////////
    // Local directories
    // Keeps the files around for viewing when building the extension by itself
    if builder.rebuild_mod() {
        let esm_path = builder.local_build_path.join("@esm");

        // Delete @esm and recreate it
        if esm_path.exists() {
            fs::remove_dir_all(&esm_path)?;
            fs::create_dir_all(&esm_path)?;
        }

        // Create @esm/addons
        let addons_path = esm_path.join("addons");
        if !addons_path.exists() {
            fs::create_dir_all(&addons_path)?;
        }
    }

    // Remove some build files
    let paths = vec![
        "@esm.zip",
        "windows.zip",
        "linux.zip",
        "esm.zip",
        ".esm-build-command",
        ".esm-build-command-result",
    ];

    for path in paths {
        let path = builder.local_build_path.join(path);
        if path.exists() && path.is_file() {
            fs::remove_file(&path)?;
        }
    }

    /////////////////////
    // Remote directories
    match builder.os {
        BuildOS::Windows => {
            lazy_static! {
                static ref PROFILES_REGEX: Regex = Regex::new(r#"-profiles=(\w+)"#).unwrap();
            };

            let captures = PROFILES_REGEX
                .captures(&builder.remote.server_args)
                .unwrap();
            let profile_name = match captures.get(1) {
                    Some(n) => n.as_str(),
                    None => return Err(
                        "\"-profiles\" must be provided in the server args. This is required for log streaming"
                            .to_string()
                            .into(),
                    ),
                };

            let script = format!(
                r#"
                        Remove-Item "{server_path}\{profile_name}\*.log" -ErrorAction SilentlyContinue;
                        Remove-Item "{server_path}\{profile_name}\*.rpt" -ErrorAction SilentlyContinue;
                        Remove-Item "{server_path}\{profile_name}\*.bidmp" -ErrorAction SilentlyContinue;
                        Remove-Item "{server_path}\{profile_name}\*.mdmp" -ErrorAction SilentlyContinue;

                        New-Item -Path "{build_path}\esm" -ItemType Directory;
                        New-Item -Path "{build_path}\@esm" -ItemType Directory;
                        New-Item -Path "{build_path}\@esm\addons" -ItemType Directory;
                        New-Item -Path "{server_path}\@esm" -ItemType Directory;
                        New-Item -Path "{server_path}\@esm\addons" -ItemType Directory;
                    "#,
                build_path = builder.remote_build_path_str(),
                server_path = builder.remote.server_path,
                profile_name = profile_name
            );

            builder.system_command(
                System::new()
                    .command(script)
                    .add_detection("error", true)
                    .wait(),
            )?;
        }
        BuildOS::Linux => (),
    };

    Ok(())
}

pub fn prepare_to_build(builder: &mut Builder) -> BuildResult {
    kill_arma(builder)?;
    detect_first_build(builder)?;
    prepare_directories(builder)?;
    transfer_mikeros_tools(builder)?;
    create_server_config(builder)?;
    create_esm_key_file(builder)?;
    Ok(())
}

pub fn transfer_mikeros_tools(builder: &mut Builder) -> BuildResult {
    let mikero_path = builder
        .local_git_path
        .join("tools")
        .join("pbo_tools")
        .join(builder.os.to_string());

    Directory::transfer(builder, mikero_path, builder.remote_build_path().to_owned())
}

pub fn create_server_config(builder: &mut Builder) -> BuildResult {
    #[derive(Debug, PartialEq, Serialize, Deserialize)]
    struct Config {
        connection_url: String,
        log_level: String,
        env: String,
        log_output: String,
    }

    let config = Config {
        connection_url: builder.bot_host.clone(),
        log_level: builder.log_level.to_string(),
        env: builder.env.to_string(),
        log_output: "rpt".into(),
    };

    let config_yaml = serde_yaml::to_vec(&config)?;
    fs::write(
        builder
            .local_build_path
            .join("config.yml")
            .to_string_lossy()
            .to_string(),
        config_yaml,
    )?;

    crate::File::transfer(
        builder,
        builder.local_build_path.to_owned(),
        builder.remote_build_path().join("@esm"),
        "config.yml",
    )?;

    Ok(())
}

pub fn create_esm_key_file(builder: &mut Builder) -> BuildResult {
    let mut connection = builder.redis.get_connection()?;
    let mut last_key_received = String::new();

    // Moved to a thread so this can happen over and over again for testing purposes
    thread::spawn(move || loop {
        let key: Option<String> = redis::cmd("GET")
            .arg(REDIS_SERVER_KEY)
            .query(&mut connection)
            .unwrap();

        let Some(key) = key else {
                thread::sleep(Duration::from_millis(500));
                continue;
            };

        if key == last_key_received {
            thread::sleep(Duration::from_millis(500));
            continue;
        }

        write_lock(&crate::SERVER, |mut server| {
            server.send(Command::Key(key.to_owned()))?;
            Ok(true)
        })
        .unwrap();

        last_key_received = key.to_owned();
    });

    Ok(())
}

pub fn detect_first_build(builder: &mut Builder) -> BuildResult {
    let extension_file_name = match builder.arch {
        BuildArch::X32 => "esm",
        BuildArch::X64 => "esm_x64",
    };

    let mut files_to_check: Vec<String> = ADDONS
        .iter()
        .map(|addon| format!(r"addons\{addon}.pbo"))
        .collect();

    if matches!(builder.env, BuildEnv::Test) {
        files_to_check.push(r"addons\esm_test.pbo".to_string());
    }

    let script = match builder.os {
        BuildOS::Windows => {
            files_to_check.push(format!("{extension_file_name}.dll"));

            files_to_check
                .iter()
                .map(|path| {
                    format!(
                        r#"
                                if (![System.IO.File]::Exists("{server_path}\@esm\{path}")) {{
                                    return "rebuild";
                                }}
                            "#,
                        server_path = builder.remote.server_path
                    )
                })
                .collect::<Vec<String>>()
                .join("\n")
        }
        BuildOS::Linux => todo!(),
    };

    let result = builder.system_command(
        System::new()
            .command(script)
            .add_detection("rebuild.*", false),
    )?;

    let Command::SystemResponse(result) = result else {
            return Err("Invalid response for System command. Must be Command::SystemResponse".to_string().into());
        };

    if result == *"rebuild" {
        // This may be a first build - build all the things!
        builder.force = true;
    }

    Ok(())
}

pub fn build_extension(builder: &mut Builder) -> BuildResult {
    // This will be read by the build script and inserted into the extension
    let extension_path = builder.local_git_path.join("src").join("arma");
    let message_path = builder.local_git_path.join("src").join("message");

    fs::write(
        extension_path
            .join(".build-sha")
            .to_string_lossy()
            .to_string(),
        git_sha_short().as_bytes(),
    )?;

    // Copy the extension and message code over to the remote host
    Directory::transfer(builder, extension_path, builder.remote_build_path().to_owned())?;
    Directory::transfer(builder, message_path, builder.remote_build_path().to_owned())?;

    match builder.os {
        BuildOS::Windows => {
            let script = format!(
                r#"
                        cd '{build_path}\arma';
                        rustup run stable-{build_target} cargo build --target {build_target} --release;

                        Copy-Item "{build_path}\arma\target\{build_target}\release\esm_arma.dll" -Destination "{build_path}\@esm\{file_name}.dll"
                    "#,
                build_path = builder.remote_build_path_str(),
                build_target = builder.extension_build_target,
                file_name = match builder.arch {
                    BuildArch::X32 => "esm",
                    BuildArch::X64 => "esm_x64",
                }
            );

            builder.system_command(
                System::new()
                    .command(script)
                    .add_detection(r"error: .+", true)
                    .add_detection(r"warning", false),
            )?;
        }
        BuildOS::Linux => todo!(),
    }

    Ok(())
}

pub fn check_for_p_drive(builder: &mut Builder) -> BuildResult {
    assert!(matches!(builder.os, BuildOS::Windows));

    let script = r#"
            if (Get-PSDrive P -ErrorAction SilentlyContinue) {{
                "p_drive_mounted";
            }} else {{
                "p_drive_not_mounted";
            }}
        "#;

    let result = builder.system_command(
        System::new()
            .command(script)
            .add_detection("p_drive_mounted", false),
    )?;

    // Continue building
    if let Command::SystemResponse(r) = result {
        if r == *"p_drive_mounted" {
            return Ok(());
        }
    } else {
        panic!("Invalid response for System command. Must be Command::SystemResponse");
    }

    // WorkDrive.exe will keep a window open that requires user input
    println!("{}", "paused\nWaiting for input...".yellow());
    println!("Please confirm Window's UAC and then press any key on the window that WorkDrive has opened");

    let script = format!(
        r#"
                Start-Process -Wait -FilePath "{build_path}\windows\WorkDrive.exe" -ArgumentList "/Mount";

                if (Get-PSDrive P -ErrorAction SilentlyContinue) {{
                    "p_drive_mounted";
                }} else {{
                    "p_drive_not_mounted";
                }}
            "#,
        build_path = builder.remote_build_path_str(),
    );

    builder.system_command(
        System::new()
            .command(script)
            .add_detection("p_drive_not_mounted", true),
    )?;
    Ok(())
}

pub fn compile_mod(builder: &mut Builder) -> BuildResult {
    lazy_static! {
        static ref DIRECTORIES: Vec<&'static str> = vec!["optionals", "sql"];
        static ref FILES: Vec<&'static str> = vec!["Licenses.txt"];
    }

    // Set up all the paths needed
    let mod_path = builder.local_git_path.join("src").join("@esm");
    let source_path = mod_path.join("addons");

    let mod_build_path = builder.local_build_path.join("@esm");
    let addon_destination_path = mod_build_path.join("addons");

    let mut compiler = Compiler::new();
    compiler
        .source(&source_path.to_string_lossy())
        .destination(&addon_destination_path.to_string_lossy())
        .target(&builder.os.to_string());

    crate::compile::bind_replacements(&mut compiler);
    compiler.compile()?;

    Directory::transfer(builder, mod_build_path, builder.remote_build_path().to_owned())?;

    Ok(())
}

pub fn build_mod(builder: &mut Builder) -> BuildResult {
    compile_mod(builder)?;

    match builder.os {
        BuildOS::Linux => todo!(),
        BuildOS::Windows => {
            let mut extra_addons = vec![];
            if matches!(builder.env, BuildEnv::Test) {
                extra_addons.push("esm_test");
            }

            for addon in ADDONS.iter().chain(extra_addons.iter()) {
                if !builder.rebuild_addon(addon) {
                    continue;
                }

                // The "root" is what matters here. The root needs to be P: drive
                let script = format!(
                    r#"
                            if ([System.IO.Directory]::Exists("P:\{addon}")) {{
                                Remove-Item -Path "P:\{addon}" -Recurse;
                            }}

                            Move-Item -Force -Path "{build_path}\@esm\addons\{addon}" -Destination "P:";
                            Start-Process -Wait -NoNewWindow -FilePath "{build_path}\windows\MakePbo.exe" -ArgumentList "-P", "P:\{addon}", "{build_path}\@esm\addons\{addon}.pbo";

                            if (!([System.IO.File]::Exists("{build_path}\@esm\addons\{addon}.pbo"))) {{
                                "Failed to build - {build_path}\@esm\addons\{addon}.pbo does not exist"
                            }}
                        "#,
                    build_path = builder.remote_build_path_str(),
                );

                builder.system_command(
                    System::new()
                        .command(script)
                        .add_detection("ErrorId", true)
                        .add_detection("Failed to build", true)
                        .add_detection("missing file", true),
                )?;
            }
        }
    }

    Ok(())
}

pub fn seed_database(build: &mut Builder) -> BuildResult {
    let sql = Database::generate_sql(&build.config);
    match build.send_to_receiver(Command::Database(sql)) {
        Ok(_) => Ok(()),
        Err(e) => Err(e),
    }
}

pub fn start_a3_server(build: &mut Builder) -> BuildResult {
    match build.os {
        BuildOS::Windows => {
            let script = format!(
                r#"
                        Remove-Item -Path "{server_path}\@esm" -Recurse;
                        Copy-Item -Path "{build_path}\@esm" -Destination "{server_path}\@esm" -Recurse;

                        Start-Process "{server_path}\{server_executable}" `
                            -ArgumentList "{server_args}" `
                            -WorkingDirectory "{server_path}";
                    "#,
                build_path = build.remote_build_path_str(),
                server_path = build.remote.server_path,
                server_executable = match build.arch {
                    BuildArch::X32 => "arma3server.exe",
                    BuildArch::X64 => "arma3server_x64.exe",
                },
                server_args = build.remote.server_args
            );

            build.system_command(System::new().command(script))?;
        }
        BuildOS::Linux => todo!(),
    }

    Ok(())
}

// pub fn start_a3_client(build: &mut Builder) -> BuildResult {
//     // client arg: client start args
//     // Send command to receiver
//     // Issue! In order to start the client on linux, both the linux machine and windows machine will need to be connected
//     //          This will need to be solved.
//     Ok(())
// }

pub fn stream_logs(build: &mut Builder) -> BuildResult {
    struct Highlight {
        pub regex: Regex,
        pub color: [u8; 3],
    }

    lazy_static! {
        static ref HIGHLIGHTS: Vec<Highlight> = vec![
            Highlight {
                regex: Regex::new(r"ERROR\b").unwrap(),
                color: [153, 0, 51]
            },
            Highlight {
                regex: Regex::new(r"WARN").unwrap(),
                color: [153, 102, 0]
            },
            Highlight {
                regex: Regex::new(r"INFO").unwrap(),
                color: [102, 204, 255]
            },
            Highlight {
                regex: Regex::new(r"DEBUG").unwrap(),
                color: [80, 82, 86]
            },
            Highlight {
                regex: Regex::new(r"TRACE").unwrap(),
                color: [255, 153, 102]
            }
        ];
    }

    build.send_to_receiver(Command::LogStreamInit)?;

    loop {
        let result = build.send_to_receiver(Command::LogStreamRequest)?;
        let lines = match result {
            Command::LogStream(l) => l,
            c => {
                return Err(
                    format!("Invalid response to LogStreamRequest. Received {:?}", c).into(),
                )
            }
        };

        for line in lines {
            let content = line.content.trim_end();
            let extension = Path::new(&line.filename)
                .extension()
                .unwrap()
                .to_string_lossy()
                .to_string();

            let highlight = HIGHLIGHTS.iter().find(|h| h.regex.is_match(content));

            println!(
                "{name}:{line_number:5}{sep} {content}",
                sep = "|".bright_black(),
                name = extension.truecolor(line.color[0], line.color[1], line.color[2]),
                line_number = line.line_number.to_string().bright_black(),
                content = if let Some(h) = highlight {
                    content.bold().truecolor(h.color[0], h.color[1], h.color[2])
                } else {
                    content.normal()
                }
            )
        }
    }
}
