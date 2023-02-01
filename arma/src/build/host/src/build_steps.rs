use crate::*;

use colored::*;
use common::{BuildResult, Command};
use compiler::Compiler;
use lazy_static::lazy_static;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{fs, path::Path, thread, time::Duration};

pub fn start_container(_builder: &mut Builder) -> BuildResult {
    if !is_container_running() {
        System::new()
            .command("docker")
            .arguments(&["compose", "up", "-d"])
            .execute(None)?;
    }

    Ok(())
}

pub fn wait_for_container(_builder: &mut Builder) -> BuildResult {
    const TIMEOUT: i32 = 30; // Seconds
    let mut counter = 0;

    loop {
        if is_container_running() || counter >= TIMEOUT {
            break;
        }

        counter += 1;
        thread::sleep(Duration::from_secs(1));
    }

    if counter >= TIMEOUT {
        return Err("Failed to connect to the Docker container"
            .to_string()
            .into());
    }

    Ok(())
}

pub fn check_for_files(builder: &mut Builder) -> BuildResult {
    let exile_path = builder
        .local_git_path
        .join("server")
        .join("@exile")
        .join("addons");

    if exile_path.join("exile_client.pbo").exists() {
        return Ok(());
    }

    Err(format!(
        "Failed to find require files in server/@exile.\nPlease download the client files for Exile Mod and copy the contents from its addons to \"{}\"",
        exile_path.display()
    )
    .into())
}

pub fn update_arma(builder: &mut Builder) -> BuildResult {
    // ExileMod on Steam workshop
    // +workshop_download_item 233780 1487484880 \
    // Only works if the Steam account owns the mod
    // Since steam guard has to be disabled for this to work, I opted to not require owning
    // Arma 3 on this account
    let script = format!(
        r#"
cd /steamcmd;
./steamcmd.sh +force_install_dir {ARMA_PATH} \
    +login {steam_username} {steam_password} \
    +app_update 233780 validate \
    +quit;
"#,
        steam_username = builder.config.server.steam_user,
        steam_password = builder.config.server.steam_password
    );

    System::new()
        .command("bash")
        .arguments(&[
            "-c",
            &format!("docker exec -t {ARMA_CONTAINER} /bin/bash -c \"{script}\""),
        ])
        .add_error_detection("error!")
        .print_as("steamcmd")
        .print_stdout()
        .execute(None)?;

    Ok(())
}

pub fn prepare_receiver(builder: &mut Builder) -> BuildResult {
    stop_receiver()?;
    build_receiver(builder)?;
    start_receiver()
}

pub fn build_receiver(builder: &mut Builder) -> BuildResult {
    let git_path = builder.local_git_path.to_string_lossy();
    let build_path = builder.local_git_path.join("src").join("build");
    let docker_tmp_path = Path::new("/tmp/esm");

    let build_copy_script = |directory: &str, copy_script: &mut String| {
        let module_changed =
            has_directory_changed(&builder.file_watcher, &build_path.join(directory))
                || !docker_dir_exists(&docker_tmp_path.join(directory).join("src"));

        if module_changed {
            copy_script.push_str(&format!(
                "
                    docker exec -t {ARMA_CONTAINER} /bin/bash -c 'mkdir -p /tmp/esm/{directory} || rm -rf /tmp/esm/{directory}';
                    docker compose cp {git_path}/src/build/{directory} {ARMA_SERVICE}:/tmp/esm/;
                "
            ));
        }
    };

    // Copy to container
    let mut copy_script = String::new();
    build_copy_script("receiver", &mut copy_script);
    build_copy_script("common", &mut copy_script);
    build_copy_script("compiler", &mut copy_script);

    if copy_script.is_empty() {
        return Ok(());
    }

    System::new()
        .script(copy_script)
        .add_error_detection("no such")
        .print()
        .print_as("cp (receiver)")
        .execute(None)?;

    // Build receiver
    System::new()
        .command("docker")
        .arguments(&[
            "exec",
            "-t",
            ARMA_CONTAINER,
            "/bin/bash",
            "-c",
            &format!(
                "cargo build --release --manifest-path={}",
                docker_tmp_path
                    .join("receiver")
                    .join("Cargo.toml")
                    .display()
            ),
        ])
        .add_error_detection("no such")
        .print_as("cargo (receiver)")
        .print()
        .execute(None)?;

    // Create script to run receiver in container
    let receiver_script = format!(
        r#"#!/bin/bash
/arma3server/receiver \
--host=host.docker.internal:54321 \
--database-uri={} \
--a3-server-path={ARMA_PATH} \
--a3-server-args=\"{}\" \
>> receiver.log
"#,
        builder.config.server.mysql_uri,
        builder
            .config
            .server
            .server_args
            .iter()
            .map(|arg| format!("-{arg}"))
            .collect::<Vec<String>>()
            .join(" ")
    );

    // Send receiver script and setup for execution
    System::new()
        .command("docker")
        .arguments(&[
            "exec",
            "-t",
            ARMA_CONTAINER,
            "/bin/bash",
            "-c",
            &format!(
                "echo \"{receiver_script}\" > {ARMA_PATH}/start_receiver.sh && chmod +x {ARMA_PATH}/start_receiver.sh && cp {} {ARMA_PATH}/ && chmod +x {ARMA_PATH}/receiver",
                docker_tmp_path.join("receiver").join("target").join("release").join("receiver").display()
            ),
        ])
        .add_error_detection("no such")
        .print_as("bash (start script)")
        .print()
        .execute(None)?;

    Ok(())
}

pub fn prepare_to_build(builder: &mut Builder) -> BuildResult {
    kill_arma(builder)?;
    detect_rebuild(builder)?;
    prepare_directories(builder)?;
    // transfer_mikeros_tools(builder)?;
    create_server_config(builder)?;
    create_esm_key_file(builder)
}

pub fn kill_arma(builder: &mut Builder) -> BuildResult {
    match builder.args.build_os() {
        BuildOS::Linux => {
            System::new()
                .script(&format!(
                    "for pid in $(ps -ef | awk '/{}/ {{print $2}}'); do kill -9 $pid; done",
                    LINUX_EXES.join("|")
                ))
                .execute_remote(&builder.build_server)?;
        }
        BuildOS::Windows => {
            System::new()
                .script(
                    WINDOWS_EXES
                    .iter()
                    .map(|exe| format!("Get-Process -Name '{exe}' -ErrorAction SilentlyContinue | Stop-Process -Force;"))
                    .collect::<Vec<String>>().join(" "))
                .execute_remote(&builder.build_server)?;
        }
    }

    Ok(())
}

pub fn detect_rebuild(builder: &mut Builder) -> BuildResult {
    let extension_file_name = match builder.args.build_arch() {
        BuildArch::X32 => "esm",
        BuildArch::X64 => "esm_x64",
    };

    let path_separator = match builder.args.build_os() {
        BuildOS::Linux => "/",
        BuildOS::Windows => "\\",
    };

    let mut files_to_check: Vec<String> = ADDONS
        .iter()
        .map(|addon| format!(r"addons{path_separator}{addon}.pbo"))
        .collect();

    if matches!(builder.args.build_env(), BuildEnv::Test) {
        files_to_check.push(format!(r"addons{path_separator}esm_test.pbo"));
    }

    let script = match builder.args.build_os() {
        BuildOS::Windows => {
            files_to_check.push(format!("{extension_file_name}.dll"));

            files_to_check
                .iter()
                .map(|path| {
                    format!(
                        "if (![System.IO.File]::Exists('{server_path}\\@esm\\{path}')) {{ Write-Output('rebuild'); }};",
                        server_path = builder.remote.server_path
                    )
                })
                .collect::<Vec<String>>()
                .join("\n")
        }
        BuildOS::Linux => {
            files_to_check.push(format!("{extension_file_name}.so"));

            let files = files_to_check
                .iter()
                .map(|path| format!("\"{path}\""))
                .collect::<Vec<String>>()
                .join(" ");

            format!(
                r#"
files=({files});
for file in ${{files[@]}}; do [[ ! -f "{server_path}/@esm/$file" ]] && echo "rebuild" && exit 0; done; exit 0
"#,
                server_path = builder.remote.server_path
            )
        }
    };

    let result = System::new()
        .script(script)
        .add_detection("rebuild")
        .execute_remote(&builder.build_server)?;

    // TODO: change scripts to output a different string for mod/extension rebuild
    if result == "rebuild" {
        // This may be a first build - build all the things!
        builder.rebuild_mod = true;
        builder.rebuild_extension = true;
    }

    // Rebuild the mod if the compiler has changed
    let compiler_changed = builder.file_watcher.was_modified(
        &builder
            .local_git_path
            .join("src")
            .join("build")
            .join("host")
            .join("src")
            .join("compile.rs"),
    ) || has_directory_changed(
        &builder.file_watcher,
        &builder
            .local_git_path
            .join("src")
            .join("build")
            .join("compiler"),
    );

    if compiler_changed {
        builder.rebuild_mod = true;
    }

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
    lazy_static! {
        static ref PROFILES_REGEX: Regex = Regex::new(r#"-profiles=(\w+)"#).unwrap();
    };

    let profile_name = match PROFILES_REGEX.captures(&builder.remote.server_args) {
        Some(c) => match c.get(1) {
            Some(n) => n.as_str(),
            None => return Err(
                "\"-profiles\" must be provided in the server args. This is required for log streaming"
                    .to_string()
                    .into(),
            ),
        },
        None => return Err(
            "\"-profiles\" must be provided in the server args. This is required for log streaming"
                .to_string()
                .into(),
        ),
    };

    let script = match builder.args.build_os() {
        BuildOS::Windows => {
            format!(
                "
                    Remove-Item '{server_path}\\{profile_name}\\*.log' -ErrorAction SilentlyContinue;
                    Remove-Item '{server_path}\\{profile_name}\\*.rpt' -ErrorAction SilentlyContinue;
                    Remove-Item '{server_path}\\{profile_name}\\*.bidmp' -ErrorAction SilentlyContinue;
                    Remove-Item '{server_path}\\{profile_name}\\*.mdmp' -ErrorAction SilentlyContinue;

                    if ([bool]::Parse('{rebuild_mod}')) {{
                        Remove-Item '{build_path}\\@esm' -Recurse -ErrorAction SilentlyContinue;
                    }};

                    if ([bool]::Parse('{rebuild_extension}')) {{
                        Remove-Item '{build_path}\\esm' -Recurse -ErrorAction SilentlyContinue;
                    }}

                    New-Item -Path '{build_path}\\esm' -ItemType Directory -ErrorAction SilentlyContinue;
                    New-Item -Path '{build_path}\\@esm' -ItemType Directory -ErrorAction SilentlyContinue;
                    New-Item -Path '{build_path}\\@esm\\addons' -ItemType Directory -ErrorAction SilentlyContinue;
                    New-Item -Path '{server_path}\\@esm' -ItemType Directory -ErrorAction SilentlyContinue;
                    New-Item -Path '{server_path}\\@esm\\addons' -ItemType Directory -ErrorAction SilentlyContinue;
                ",
                build_path = builder.remote_build_path_str(),
                server_path = builder.remote.server_path,
                rebuild_mod = builder.rebuild_mod(),
                rebuild_extension = builder.rebuild_extension()
            )
        }
        BuildOS::Linux => format!(
            r#"
                rm -f "{server_path}/{profile_name}/*.log";
                rm -f "{server_path}/{profile_name}/*.rpt";
                rm -f "{server_path}/{profile_name}/*.bidmp";
                rm -f "{server_path}/{profile_name}/*.mdmp";
                rm -rf "{server_path}/@esm";

                [[ {rebuild_mod} ]] && rm -rf "{build_path}/@esm";
                [[ {rebuild_extension} ]] && rm -rf "{build_path}/esm";

                mkdir -p "{server_path}/@esm/addons";
            "#,
            build_path = builder.remote_build_path_str(),
            server_path = builder.remote.server_path,
            rebuild_mod = builder.rebuild_mod(),
            rebuild_extension = builder.rebuild_extension()
        ),
    };

    System::new()
        .script(script)
        .add_error_detection("error")
        .print()
        .execute_remote(&builder.build_server)?;

    Ok(())
}

pub fn transfer_mikeros_tools(builder: &mut Builder) -> BuildResult {
    let mikero_path = builder
        .local_git_path
        .join("tools")
        .join("pbo_tools")
        .join(builder.args.build_os().to_string());

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
        connection_url: builder.args.bot_host().to_string(),
        log_level: builder.args.log_level().to_string(),
        env: builder.args.build_env().to_string(),
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
    let build_server = builder.build_server.clone();
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

        if let Err(e) = build_server.send(Command::Key(key.to_owned())) {
            println!(
                "{} - {} - {}",
                "<esm_bt>".blue().bold(),
                "failed to set key".red().bold(),
                e
            );

            continue;
        };

        last_key_received = key.to_owned();
    });

    Ok(())
}

pub fn check_for_p_drive(builder: &mut Builder) -> BuildResult {
    assert!(matches!(builder.args.build_os(), BuildOS::Windows));

    let script = r#"
            if (Get-PSDrive P -ErrorAction SilentlyContinue) {{
                "p_drive_mounted";
            }} else {{
                "p_drive_not_mounted";
            }}
        "#;

    let result = System::new()
        .script(script)
        .add_detection("p_drive_mounted")
        .execute_remote(&builder.build_server)?;

    // Continue building
    if result == "p_drive_mounted" {
        return Ok(());
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

    System::new()
        .command(script)
        .add_error_detection("p_drive_not_mounted")
        .execute_remote(&builder.build_server)?;

    Ok(())
}

pub fn compile_mod(builder: &mut Builder) -> BuildResult {
    lazy_static! {
        static ref DIRECTORIES: Vec<&'static str> = vec!["optionals", "sql"];
        static ref FILES: Vec<&'static str> = vec!["Licenses.txt"];
    }

    // Set up all the paths needed
    let source_path = builder
        .local_git_path
        .join("src")
        .join("@esm")
        .join("addons");

    let mod_build_path = builder.local_build_path.join("@esm");
    let addon_destination_path = mod_build_path.join("addons");

    let mut compiler = Compiler::new();
    compiler
        .source(&source_path.to_string_lossy())
        .destination(&addon_destination_path.to_string_lossy())
        .target(&builder.args.build_os().to_string());

    crate::compile::bind_replacements(&mut compiler);
    compiler.compile()?;

    // Directory::transfer(
    //     builder,
    //     mod_build_path,
    //     builder.remote_build_path().to_owned(),
    // )?;

    Ok(())
}

pub fn build_mod(builder: &mut Builder) -> BuildResult {
    compile_mod(builder)?;

    let mut extra_addons = vec![];
    if matches!(builder.args.build_env(), BuildEnv::Test) {
        extra_addons.push("esm_test");
    }

    let build_path = builder.local_build_path.join("@esm").join("addons");

    for addon in ADDONS.iter().chain(extra_addons.iter()) {
        if !builder.rebuild_addon(addon) {
            continue;
        }

        let script = format!(
            r#"
destination_file="{addon}.pbo";

cd {build_path};
armake2 pack -v "{addon}" "$destination_file";

if [[ -f "$destination_file" ]]; then
    rm -rf {addon};
else
    echo "Failed to build - $destination_file does not exist";
fi
"#,
            build_path = build_path.display()
        );

        System::new()
            .script(script)
            .add_error_detection("ErrorId")
            .add_error_detection("Failed to build")
            .add_error_detection("missing file")
            .execute(None)?;
    }

    Directory::transfer(
        builder,
        build_path,
        builder.remote_build_path().join("@esm"),
    )?;

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
    Directory::transfer(
        builder,
        extension_path,
        builder.remote_build_path().to_owned(),
    )?;
    Directory::transfer(
        builder,
        message_path,
        builder.remote_build_path().to_owned(),
    )?;

    let script = match builder.args.build_os() {
        BuildOS::Windows => {
            format!(
                "
                    cd '{build_path}\\arma';
                    rustup run stable-{build_target} cargo build --target {build_target} --release;
                    Copy-Item '{build_path}\\arma\\target\\{build_target}\\release\\esm_arma.dll' -Destination '{build_path}\\@esm\\{file_name}.dll';
                ",
                build_path = builder.remote_build_path_str(),
                build_target = builder.extension_build_target,
                file_name = match builder.args.build_arch() {
                    BuildArch::X32 => "esm",
                    BuildArch::X64 => "esm_x64",
                }
            )
        }
        BuildOS::Linux => {
            format!(
                r#"
cd {build_path}/arma;
rustup run stable-{build_target} cargo build --target {build_target} --release;

cp "{build_path}/arma/target/{build_target}/release/libesm_arma.so" "{build_path}/@esm/{file_name}.so"
"#,
                build_path = builder.remote_build_path_str(),
                build_target = builder.extension_build_target,
                file_name = match builder.args.build_arch() {
                    BuildArch::X32 => "esm",
                    BuildArch::X64 => "esm_x64",
                }
            )
        }
    };

    System::new()
        .script(script)
        .add_error_detection(r"error: .+")
        .add_detection(r"warning")
        .print_as("cargo (esm)")
        .print_to_remote()
        .execute_remote(&builder.build_server)?;

    Ok(())
}

pub fn seed_database(builder: &mut Builder) -> BuildResult {
    let sql = Database::generate_sql(&builder.config);
    match builder.build_server.send(Command::Database(sql)) {
        Ok(_) => Ok(()),
        Err(e) => Err(e),
    }
}

pub fn start_a3_server(builder: &mut Builder) -> BuildResult {
    let script = match builder.args.build_os() {
        BuildOS::Windows => {
            format!(
                "
                    Remove-Item -Path '{server_path}\\@esm' -Recurse;
                    Copy-Item -Path '{build_path}\\@esm' -Destination '{server_path}\\@esm' -Recurse;

                    Start-Process '{server_path}\\{server_executable}' `
                        -ArgumentList '{server_args}' `
                        -WorkingDirectory '{server_path}';
                ",
                build_path = builder.remote_build_path_str(),
                server_path = builder.remote.server_path,
                server_executable = builder.server_executable,
                server_args = builder.remote.server_args
            )
        }
        BuildOS::Linux => {
            format!(
                r#"
rm -rf {server_path}/@esm;
cp -rf {build_path}/@esm {server_path}/@esm;
mkdir -p {ARMA_PATH}/server_profile;

{server_path}/{server_executable} {server_args} &>{ARMA_PATH}/server_profile/server.rpt &
                "#,
                build_path = builder.remote_build_path_str(),
                server_path = builder.remote.server_path,
                server_executable = builder.server_executable,
                server_args = builder.remote.server_args
            )
        }
    };

    System::new()
        .script(script)
        .execute_remote(&builder.build_server)?;

    Ok(())
}

// pub fn start_a3_client(build: &mut Builder) -> BuildResult {
//     // client arg: client start args
//     // Send command to receiver
//     // Issue! In order to start the client on linux, both the linux machine and windows machine will need to be connected
//     //          This will need to be solved.
//     Ok(())
// }

pub fn stream_logs(builder: &mut Builder) -> BuildResult {
    println!();
    builder.build_server.send(Command::LogStreamInit)?;

    loop {
        let result = builder.build_server.send(Command::LogStreamRequest)?;
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
