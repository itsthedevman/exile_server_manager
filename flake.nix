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
            "i686-pc-windows-gnu"
          ];
        };

        # 32-bit Windows cross-compile toolchain.
        #
        # nixpkgs' stock i686 mingw gcc is built with SjLj exception handling, whose
        # libgcc_eh only exports __Unwind_SjLj_* symbols. Rust's prebuilt
        # i686-pc-windows-gnu std uses the DWARF-2 unwind ABI (_Unwind_RaiseException /
        # _Unwind_Resume), so it cannot link against a SjLj libgcc. Rebuilding the cross
        # gcc with --disable-sjlj-exceptions flips i686 to DWARF-2 and makes the ABIs match.
        # (x86_64 Windows avoids all of this because it uses SEH, not SjLj/DWARF.)
        mingw32GccDwarf = pkgs.pkgsCross.mingw32.buildPackages.gcc.override {
          cc = pkgs.pkgsCross.mingw32.buildPackages.gcc.cc.overrideAttrs (o: {
            configureFlags = (o.configureFlags or [ ]) ++ [ "--disable-sjlj-exceptions" ];
          });
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

            # Windows cross-compilation (x64: SEH; x32: DWARF gcc built above)
            pkgsCross.mingwW64.buildPackages.gcc
            pkgsCross.mingwW64.buildPackages.binutils
            mingw32GccDwarf
            pkgsCross.mingw32.buildPackages.binutils

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

            # Arma: Windows cross-compile rflags. Rust's prebuilt windows-gnu std hard-links
            # -l:libpthread.a (winpthreads), which isn't on the mingw wrapper's default search
            # path, so feed it in here. The 32-bit target additionally needs the mcfgthread
            # runtime (-lmcfgthread) because the cross gcc uses the mcf thread model.
            export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-L ${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib"
            export CARGO_TARGET_I686_PC_WINDOWS_GNU_RUSTFLAGS="-L ${pkgs.pkgsCross.mingw32.windows.pthreads}/lib -L ${pkgs.pkgsCross.mingw32.windows.mcfgthreads}/lib -C link-arg=-lmcfgthread"

            # Arma: patch binary tools if they exist (only meaningful from monorepo root)
            OPENSSL_LIB="${pkgs.openssl.out}/lib"
            if [ -d arma/tools ]; then
              mkdir -p arma/tools/wrappers

              if [ -f arma/tools/sqfvm ]; then
                echo "patching arma/tools/sqfvm..."
                cp -f arma/tools/sqfvm arma/tools/wrappers/sqfvm
                patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" arma/tools/wrappers/sqfvm || true
              fi

              chmod +x arma/tools/wrappers/* 2>/dev/null || true
            fi

            # Auto-start the backing services this machine doesn't already provide:
            # nats and mysql. Postgres and redis are run systemwide (Nix services), so
            # those compose services are skipped here to avoid a port clash; the root
            # docker-compose.yml still defines all four for machines without natives.
            # Starting these also creates the `esm` network arma's compose joins.
            # Idempotent: compose only starts what isn't already running; ESM_NATS is
            # the sentinel.
            if [ -f docker-compose.yml ] && docker info >/dev/null 2>&1; then
              if [ -z "$(docker ps -q --filter "name=^ESM_NATS$" --filter "status=running" 2>/dev/null)" ]; then
                echo "Starting ESM backing services (nats, mysql)..."
                docker-compose -f docker-compose.yml up -d nats mysql_db >/dev/null 2>&1 || true
              fi
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
