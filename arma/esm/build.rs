use vergen::{vergen, Config};
use vergen::ShaKind;

fn main() {
    let mut config = Config::default();

    // Change the SHA output to the short variant
    *config.git_mut().sha_kind_mut() = ShaKind::Short;

    match vergen(config) {
      Ok(_) => (),
      Err(e) => panic!("{}", e)
    }
  }
