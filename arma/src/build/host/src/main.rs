mod compile;
mod config;
mod context;
mod display;
mod error;
mod file_watcher;
mod locks;
mod spinner;
mod string_table;
mod steps;
mod target;

use std::{
    process::exit,
    sync::atomic::{AtomicBool, Ordering},
};

use clap::Parser;
use colored::Colorize;
use context::{Args, BuildContext, InstanceContext};
use error::BuildResult;
use lazy_static::lazy_static;

pub const ADDONS: &[&str] = &[
    "exile_server_manager_updater",
    "exile_server_manager",
    "exile_server_overwrites",
    "exile_server_xm8",
    "exile_server_hacking",
    "exile_server_grinding",
    "exile_server_charge_plant_started",
    "exile_server_flag_steal_started",
    "exile_server_player_connected",
];

// Every server runs in its own container, so these paths are the same no matter which one is running. What
// differs per server is the container name, its host-side volumes, and its game port — all on `Instance`.
pub const ARMA_PATH: &str = "/arma3server";

pub const LINUX_EXES: &[&str] =
    &["/arma3server/arma3server", "/arma3server/arma3server_x64"];

lazy_static! {
    pub static ref CTRL_C_RECEIVED: AtomicBool = AtomicBool::new(false);
}

fn main() {
    lazy_static::initialize(&CTRL_C_RECEIVED);

    // Fires on SIGINT/SIGTERM/SIGHUP (the latter two via ctrlc's `termination`
    // feature) so closing the terminal or `overmind stop` still reaps the
    // server rather than orphaning arma3server in the container.
    ctrlc::set_handler(move || {
        if CTRL_C_RECEIVED.load(Ordering::SeqCst) {
            // Second signal: force exit immediately
            exit(1);
        }
        // First signal: ask the loop to stop cleanly (kill_arma runs after)
        CTRL_C_RECEIVED.store(true, Ordering::SeqCst);
    })
    .expect("Error setting signal handler");

    let args = Args::parse();

    let mut ctx = match BuildContext::new(args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!(
                "{} {}",
                "error:".truecolor(198, 37, 81).bold(),
                e
            );
            exit(1);
        }
    };

    // Detect what needs rebuilding before printing the header so the queue
    // field in the header is accurate.
    if let Err(e) = steps::detect::detect_rebuild(&mut ctx) {
        eprintln!("{} {}", "error:".truecolor(198, 37, 81).bold(), e);
        exit(1);
    }

    display::print_header(&ctx);
    println!();

    if let Err(e) = run_pipeline(&mut ctx) {
        eprintln!(
            "\n{} {}",
            "error:".truecolor(198, 37, 81).bold(),
            e
        );
        exit(1);
    }
}

fn run_pipeline(ctx: &mut BuildContext) -> BuildResult {
    use steps::{
        database, deploy, ext_build, keys, logs, mod_build, server, server_mod, staging,
    };

    // --start-only exists to leave the server's files alone, so it skips everything that would write to them:
    // the build, the deploy, and the database work below. What is left is the container coming up and the server
    // starting, which is the part it is actually asking for.
    let start_only = ctx.args.start_only();

    // --- Build phase ---
    // detect_rebuild already ran before the header was printed.
    // Held only for the build: the staging tree is the one thing every server shares.
    let build_lock = locks::BuildLock::acquire(&ctx.local_build_path)?;

    if !start_only {
        run_step(ctx, "Preparing staging", staging::prepare_staging)?;

        // Multi-spinner steps handle their own output — don't wrap in run_step.
        if ctx.rebuild_mod() {
            mod_build::build_mod(ctx)?;
        }

        if ctx.rebuild_extension() {
            ext_build::build_extension(ctx)?;
        }

        if ctx.args.release {
            run_step(ctx, "Packaging release", deploy::package_release)?;
            return Ok(());
        }

        if !ctx.args.start_server() && !ctx.args.update_arma() {
            if !ctx.rebuild_mod() && !ctx.rebuild_extension() {
                let dim = display::color::DIM;
                println!(
                    "  {}",
                    "Nothing to build.".truecolor(dim.0, dim.1, dim.2).italic()
                );
            }
            return Ok(());
        }
    }

    // --- Orchestration phase ---
    run_step(ctx, "Checking Exile files", server::check_for_exile_files)?;

    // Containers are a Linux-target concern. Skipped at the call site rather than inside the step, so a Windows
    // run does not report having done work that never happened.
    let uses_containers = matches!(ctx.args.build_os(), context::BuildOS::Linux);

    if uses_containers {
        run_step(ctx, "Removing stale containers", server::remove_orphaned_containers)?;
    }

    let instances = ctx.instances.clone();
    let contexts = instances
        .iter()
        .map(|instance| InstanceContext::new(ctx, instance))
        .collect::<Result<Vec<_>, _>>()?;

    // Claimed before anything touches a container, and held for the rest of the run.
    let _server_locks = contexts
        .iter()
        .map(|ictx| locks::ServerLock::acquire(&ictx.instance_staging_path(), &ictx.instance.server_id))
        .collect::<Result<Vec<_>, _>>()?;

    if uses_containers {
        for ictx in &contexts {
            run_instance_step(ictx, "Ensuring container", server::ensure_container)?;
        }
    }

    // The Arma install is shared by every server on a target, so one update covers all of them. Not wrapped in
    // run_step: it streams SteamCMD's output and handles its own spinner.
    if !start_only && server::needs_arma_update(&contexts[0]) {
        server::update_arma(&contexts[0])?;
    }

    if !ctx.args.start_server() {
        return Ok(());
    }

    for ictx in &contexts {
        run_instance_step(ictx, "Stopping server", server::kill_arma)?;
        run_instance_step(ictx, "Cleaning logs", server::clean_logs)?;

        // Every one of these writes to the server. Deploying is the loud one, since it empties @esm before
        // uploading, but the server mod and the database seed replace state too.
        if !start_only {
            // Before the server mod, because it is the slow one and a missing @exile is the failure most likely
            // to be mistaken for a broken build.
            server_mod::sync_shared_content(ictx)?;
            run_instance_step(ictx, "Preparing server mod", server_mod::prepare_server_mod)?;
            // Windows only, and skipped at the call site rather than inside the step so a Linux run does not
            // report having installed something that does not exist there.
            if !uses_containers {
                run_instance_step(ictx, "Installing runtime", server_mod::install_windows_runtime)?;
            }
            run_instance_step(ictx, "Ensuring database", database::ensure_database)?;
            run_instance_step(ictx, "Seeding database", database::seed_database)?;
            run_instance_step(ictx, "Deploying", deploy::deploy)?;
        }

        run_instance_step(ictx, "Starting server", server::start_server)?;

        // Kept: it only watches for a key the bot publishes, so a server whose key was rotated can still connect.
        keys::start_key_exchange(ictx)?;
    }

    // Everything that touches the shared staging tree is done. Streaming runs for as long as the server does,
    // so holding the lock across it would stop any other server from ever starting.
    drop(build_lock);

    let result = logs::stream_logs(&contexts);

    // Kill every server whenever we stop streaming (CTRL-C or error)
    for ictx in &contexts {
        server::kill_arma(ictx).ok();
    }

    result
}

fn run_step(
    ctx: &mut BuildContext,
    label: &str,
    step: fn(&mut BuildContext) -> BuildResult,
) -> BuildResult {
    let sp = spinner::Spinner::start(label);
    match step(ctx) {
        Ok(()) => { sp.done(); Ok(()) }
        Err(e) => { sp.fail(); Err(e) }
    }
}

fn run_instance_step(
    ictx: &InstanceContext,
    label: &str,
    step: fn(&InstanceContext) -> BuildResult,
) -> BuildResult {
    // Only name the server once more than one is in play; a single-server run reads better without it.
    let label = if ictx.build.instances.len() > 1 {
        format!("{label} ({})", ictx.instance.server_id)
    } else {
        label.to_string()
    };

    let sp = spinner::Spinner::start(&label);
    match step(ictx) {
        Ok(()) => { sp.done(); Ok(()) }
        Err(e) => { sp.fail(); Err(e) }
    }
}
