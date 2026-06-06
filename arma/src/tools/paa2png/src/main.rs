//! One-off converter: Arma PAA texture -> PNG (or any format the `image` crate
//! infers from the output extension). Backed by HEMTT's `hemtt-paa` reader.
//!
//!     paa2png <input.paa> [output.png]
//!
//! With no output path, writes alongside the input with a `.png` extension.

use std::path::PathBuf;

use hemtt_paa::Paa;

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = std::env::args().skip(1);

    let Some(input) = args.next() else {
        return Err("usage: paa2png <input.paa> [output.png]".into());
    };
    let input = PathBuf::from(input);

    let output = args
        .next()
        .map(PathBuf::from)
        .unwrap_or_else(|| input.with_extension("png"));

    let paa = Paa::read(std::fs::File::open(&input)?)?;

    // maps() is in file order, which is largest mipmap first, so [0] is the
    // full-resolution image.
    let (mipmap, _) = paa.maps().first().ok_or("PAA contains no mipmaps")?;

    mipmap.get_image().save(&output)?;

    println!("wrote {}", output.display());
    Ok(())
}
