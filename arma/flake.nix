{
  description = "ESM Arma - A Rust-based server component";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Rust toolchain
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust
            rustToolchain

            # Build essentials
            pkg-config
            openssl_3
            openssl.dev

            # Docker tools (for containerization)
            docker-compose
            docker-client
            patchelf

            mysql84
          ];

          shellHook = ''
            OPENSSL_LIB="${pkgs.openssl_3.out}/lib"

            echo "setting up binary wrappers..."
            mkdir -p tools/wrappers

            echo "patching sqfvm..."
            cp -f tools/sqfvm tools/wrappers/sqfvm
            patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" tools/wrappers/sqfvm

            echo "patching armake2..."
            cp -f tools/armake2 tools/wrappers/armake2
            patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" tools/wrappers/armake2
            patchelf --set-rpath "$OPENSSL_LIB" tools/wrappers/armake2

            # Ensure they're executable
            chmod +x tools/wrappers/sqfvm tools/wrappers/armake2
          '';

          # Environment variables
          RUST_BACKTRACE = "1";
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        };
      }
    );
}
