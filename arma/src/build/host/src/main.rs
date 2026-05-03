mod compile;
mod config;
mod context;
mod display;
mod error;
mod file_watcher;
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
use context::{Args, BuildContext};
use error::BuildResult;
use lazy_static::lazy_static;

pub const ADDONS: &[&str] = &[
    "esm_updater",
    "exile_server_manager",
    "exile_server_overwrites",
    "exile_server_xm8",
    "exile_server_hacking",
    "exile_server_grinding",
    "exile_server_charge_plant_started",
    "exile_server_flag_steal_started",
    "exile_server_player_connected",
];

pub const ARMA_CONTAINER: &str = "ESM_ARMA_SERVER";
pub const ARMA_SERVICE: &str = "arma_server";
pub const ARMA_PATH: &str = "/arma3server";

pub const LINUX_EXES: &[&str] =
    &["/arma3server/arma3server", "/arma3server/arma3server_x64"];

lazy_static! {
    pub static ref CTRL_C_RECEIVED: AtomicBool = AtomicBool::new(false);
}

fn main() {
    lazy_static::initialize(&CTRL_C_RECEIVED);

    ctrlc::set_handler(move || {
        if CTRL_C_RECEIVED.load(Ordering::SeqCst) {
            // Second press: force exit immediately
            exit(1);
        }
        // First press: signal the loop to stop cleanly (kill_arma runs after)
        CTRL_C_RECEIVED.store(true, Ordering::SeqCst);
    })
    .expect("Error setting Ctrl-C handler");

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
        database, deploy, ext_build, keys, logs, mod_build, server, staging,
    };

    // --- Build phase (always runs) ---
    // detect_rebuild already ran before the header was printed.
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

    // --- Orchestration phase (requires Docker) ---
    run_step(ctx, "Ensuring container", server::ensure_container)?;
    run_step(ctx, "Checking Exile files", server::check_for_exile_files)?;

    if server::needs_arma_update(ctx) {
        run_step(ctx, "Updating Arma", server::update_arma)?;
    }

    if !ctx.args.start_server() {
        return Ok(());
    }

    run_step(ctx, "Stopping server", server::kill_arma)?;
    run_step(ctx, "Cleaning logs", server::clean_logs)?;
    run_step(ctx, "Seeding database", database::seed_database)?;
    run_step(ctx, "Deploying", deploy::deploy)?;
    run_step(ctx, "Starting server", server::start_server)?;

    keys::start_key_exchange(ctx)?;

    let result = logs::stream_logs(ctx);

    // Kill the server whenever we stop streaming (CTRL-C or error)
    server::kill_arma(ctx).ok();

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
