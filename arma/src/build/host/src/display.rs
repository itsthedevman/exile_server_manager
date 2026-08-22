/// ESM brand colors as (r, g, b) tuples.
#[allow(dead_code)]
pub mod color {
    /// Headers, branding — Toast Lavender
    pub const LAVENDER: (u8, u8, u8) = (55, 77, 113);
    /// Borders, chrome — Toast Steel Green
    pub const STEEL: (u8, u8, u8) = (47, 72, 88);
    /// Success, done — Toast Green
    pub const GREEN: (u8, u8, u8) = (159, 222, 58);
    /// Error, failed — Toast Red
    pub const RED: (u8, u8, u8) = (198, 37, 81);
    /// In-progress, warning — Toast Yellow
    pub const YELLOW: (u8, u8, u8) = (222, 202, 57);
    /// Info highlights — Toast Blue
    pub const BLUE: (u8, u8, u8) = (62, 211, 251);
    /// Accents — Toast Purple
    pub const PURPLE: (u8, u8, u8) = (121, 58, 222);
    /// Dim text, secondary
    pub const DIM: (u8, u8, u8) = (100, 100, 110);
    /// Bright white
    pub const WHITE: (u8, u8, u8) = (220, 220, 220);
}

use colored::Colorize;
use crate::context::{BuildArch, BuildContext, BuildOS};

// Minimum inner width of the box (between the │ borders).
const MIN_BOX_WIDTH: usize = 50;
// Fixed column width for the label (right-aligned).
const LABEL_COL: usize = 11;
// Left margin + label col + "  →  " separator = overhead before value.
const ROW_PREFIX: usize = 2 + LABEL_COL + 5; // "  <label>  →  "

pub fn print_header(ctx: &BuildContext) {
    let steel = color::STEEL;
    let lavender = color::LAVENDER;
    let white = color::WHITE;

    let rebuild_extension = ctx.rebuild_extension();
    let is_windows = matches!(ctx.args.build_os(), BuildOS::Windows);
    let is_x64 = matches!(ctx.args.build_arch(), BuildArch::X64);
    let ext_suffix = if is_x64 { "_x64" } else { "" };
    let ext_ext = if is_windows { "dll" } else { "so" };

    let esm_ext = format!("esm{ext_suffix}.{ext_ext}");
    let upd_ext = format!("esm_updater{ext_suffix}.{ext_ext}");
    let mut queue_parts: Vec<&str> = vec![];
    if ctx.rebuild_mod() { queue_parts.push("@esm"); }
    if rebuild_extension {
        queue_parts.push(&esm_ext);
        queue_parts.push(&upd_ext);
    }
    // The queue describes what this run will build, so a run that builds nothing says so rather than listing what
    // it would have built.
    let queue_str = if ctx.args.start_only() {
        "start only, nothing built or deployed".to_string()
    } else if queue_parts.is_empty() {
        "none".to_string()
    } else {
        queue_parts.join(", ")
    };

    let servers = ctx
        .instances
        .iter()
        .map(|instance| format!("{} :{}", instance.server_id, instance.port))
        .collect::<Vec<_>>()
        .join(", ");

    let rows: Vec<(&str, String)> = vec![
        ("queue",      queue_str),
        ("env",        if ctx.args.release { "production".into() } else { "development".into() }),
        ("log level",  ctx.args.log_level().to_string()),
        ("git dir",    shorten_path(&ctx.git_path.to_string_lossy())),
        ("build dir",  shorten_path(&ctx.local_build_path.join("@esm").to_string_lossy())),
        ("servers",    servers),
    ];

    // Compute box width to fit the longest value row.
    let max_val = rows.iter().map(|(_, v)| v.chars().count()).max().unwrap_or(0);
    let box_width = (ROW_PREFIX + max_val + 1).max(MIN_BOX_WIDTH);

    let top    = format!("┌{}┐", "─".repeat(box_width));
    let mid    = format!("├{}┤", "─".repeat(box_width));
    let bottom = format!("└{}┘", "─".repeat(box_width));
    let title  = "ESM Arma Build Tool";
    let title_padded = format!("{:^width$}", title, width = box_width);

    println!("{}", top.truecolor(steel.0, steel.1, steel.2));
    println!(
        "{}{}{}",
        "│".truecolor(steel.0, steel.1, steel.2),
        title_padded.truecolor(lavender.0, lavender.1, lavender.2).bold(),
        "│".truecolor(steel.0, steel.1, steel.2),
    );
    println!("{}", mid.truecolor(steel.0, steel.1, steel.2));

    for (label, value) in &rows {
        let val_len = value.chars().count();
        let padding = box_width.saturating_sub(ROW_PREFIX + val_len);
        println!(
            "{}{}{}{}",
            "│".truecolor(steel.0, steel.1, steel.2),
            format!("  {:>LABEL_COL$}  ", label).bold(),
            format!("→  {}{}", value, " ".repeat(padding)).truecolor(white.0, white.1, white.2),
            "│".truecolor(steel.0, steel.1, steel.2),
        );
    }

    println!("{}", bottom.truecolor(steel.0, steel.1, steel.2));
}

/// Replace the user's home directory prefix with `~`.
fn shorten_path(path: &str) -> String {
    if let Ok(home) = std::env::var("HOME") {
        if path.starts_with(&home) {
            return format!("~{}", &path[home.len()..]);
        }
    }
    path.to_string()
}

/// Returns a dot leader string that pads `label` to a fixed column width.
pub fn dot_leader(label: &str, total_width: usize) -> String {
    let dim = color::DIM;
    let label_len = label.chars().count();
    let dots = total_width.saturating_sub(label_len + 1);
    " ".repeat(1) + &"·".repeat(dots).truecolor(dim.0, dim.1, dim.2).to_string()
}

/// `├─` or `└─` tree prefix in Steel color.
pub fn tree_branch(is_last: bool) -> String {
    let steel = color::STEEL;
    if is_last {
        "   └─ ".truecolor(steel.0, steel.1, steel.2).to_string()
    } else {
        "   ├─ ".truecolor(steel.0, steel.1, steel.2).to_string()
    }
}

/// `│  ` continuation prefix for sub-process output lines.
pub fn tree_pipe() -> String {
    let steel = color::STEEL;
    "   │  ".truecolor(steel.0, steel.1, steel.2).to_string()
}
