{
  description = "ESM monorepo — bot, core, website, arma";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

        dart-sass = pkgs.dart-sass;

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
            "clippy"
          ];
          targets = [
            "x86_64-unknown-linux-gnu"
            "i686-unknown-linux-gnu"
            "x86_64-pc-windows-gnu"
          ];
        };

        db_user = "esm";
        db_pass = "password12345";
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Ruby (bot, core, website)
            (ruby_3_4.override {
              jemallocSupport = false;
              docSupport = false;
            })
            (with ruby_3_4.gems; [ htmlbeautifier ])
            bundler

            # Node (website)
            nodejs_22
            yarn
            dart-sass
            overmind

            # Databases
            postgresql_15
            redis
            hiredis
            mysql84

            # IPC broker
            nats-server

            # Ruby native gem deps
            pkg-config
            openssl
            openssl.dev
            readline
            zstd
            libyaml
            zlib
            libxml2
            libxslt
            shared-mime-info

            # Rust (arma)
            rustToolchain

            # Windows cross-compilation
            pkgsCross.mingwW64.buildPackages.gcc
            pkgsCross.mingwW64.buildPackages.binutils

            # Arma tools
            docker-compose
            docker-client
            patchelf
          ];

          shellHook = ''
            export LANG=C.UTF-8

            # Monorepo path constants. Single source of truth for Ruby, Rake,
            # shell scripts, and Docker entrypoints. Walk up from $PWD until
            # we find flake.nix so direnv can reload from any subdir without
            # baking the wrong path into ESM_ROOT_PATH.
            esm_root="$PWD"
            while [ "$esm_root" != "/" ] && [ ! -f "$esm_root/flake.nix" ]; do
              esm_root="$(dirname "$esm_root")"
            done
            export ESM_ROOT_PATH="$esm_root"
            export ESM_CORE_PATH="$ESM_ROOT_PATH/core"
            export ESM_SERVICE_PATH="$ESM_ROOT_PATH/service"
            export ESM_WEBSITE_PATH="$ESM_ROOT_PATH/website"
            export ESM_ARMA_PATH="$ESM_ROOT_PATH/arma"
            unset esm_root

            # Ruby: user gem bindir on PATH so binstubs (ruby-lsp, solargraph, etc.)
            # installed via `bundle install` are discoverable by editors and shells.
            export PATH="$(ruby -e 'puts Gem.user_dir')/bin:$PATH"

            # Website: dart-sass paths so sass-embedded uses system binary
            export SASS_PATH=${dart-sass}/bin/sass
            export SASS_EMBEDDED_HOST_PATH=${dart-sass}/bin/dart-sass-embedded
            export DART_SASS_PATH=${dart-sass}/bin/dart-sass
            export PATH=${dart-sass}/bin:$PATH
            export SASS_EMBEDDED_DISABLE_VENDOR_DOWNLOAD=true

            # Website: node_modules bin
            if [ -d website/node_modules ]; then
              export PATH=$PWD/website/node_modules/.bin:$PATH
            fi

            # Website: postgres data dir (per-project to avoid conflicts)
            export PGDATA=''${PGDATA:-$PWD/tmp/postgres}
            export POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C"

            # Arma: Windows cross-compile rflags
            export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-L ${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib"

            # Arma: patch binary tools if they exist (only meaningful from monorepo root)
            OPENSSL_LIB="${pkgs.openssl.out}/lib"
            if [ -d arma/tools ]; then
              mkdir -p arma/tools/wrappers

              if [ -f arma/tools/sqfvm ]; then
                echo "patching arma/tools/sqfvm..."
                cp -f arma/tools/sqfvm arma/tools/wrappers/sqfvm
                patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" arma/tools/wrappers/sqfvm || true
              fi

              if [ -f arma/tools/armake2 ]; then
                echo "patching arma/tools/armake2..."
                cp -f arma/tools/armake2 arma/tools/wrappers/armake2
                patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" arma/tools/wrappers/armake2 || true
                patchelf --set-rpath "$OPENSSL_LIB" arma/tools/wrappers/armake2 || true
              fi

              chmod +x arma/tools/wrappers/* 2>/dev/null || true
            fi

            # Bot: create esm PG superuser if postgres is running and user doesn't exist
            if pg_isready -q 2>/dev/null; then
              if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" 2>/dev/null | grep -q 1; then
                echo "Creating database user ${db_user}..."
                psql postgres -c "CREATE USER ${db_user} WITH SUPERUSER PASSWORD '${db_pass}';" 2>/dev/null || true
              fi
            fi

            bundle check > /dev/null 2>&1 || bundle install
          '';

          # Rust env vars
          RUST_BACKTRACE = "1";
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        };
      }
    );
}
