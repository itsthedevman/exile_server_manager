{
  description = "esm_website - Rails development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        dart-sass = pkgs.dart-sass;

        db_user = "esm_website";
        db_pass = "password12345";
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ruby_3_3
            (with ruby_3_3.gems; [
              htmlbeautifier
            ])
            bundler

            nodejs_22
            yarn
            dart-sass

            # Process managment
            overmind

            # Database
            postgresql_15
            redis
            hiredis

            # Build dependencies
            pkg-config
            openssl
            libyaml
            zlib
            libxml2
            libxslt
            shared-mime-info # Required for content-type detection
          ];

          shellHook = ''
            export LANG=C.UTF-8

            # Ruby/Rails related
            export BUNDLE_PATH=vendor/bundle
            export GEM_HOME=$PWD/vendor/bundle
            export PATH=$GEM_HOME/bin:$PATH

            # Postgres related
            export PGDATA=$PWD/tmp/postgres
            export POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C"

            # Node/Vite related
            export PATH=$PWD/node_modules/.bin:$PATH

            # Use the Nix-provided dart-sass instead of the gem's version
            export SASS_PATH=${dart-sass}/bin/sass

            # Tell the sass-embedded gem to use system's dart-sass
            export SASS_EMBEDDED_HOST_PATH=${dart-sass}/bin/dart-sass-embedded
            export DART_SASS_PATH=${dart-sass}/bin/dart-sass
            export PATH=${dart-sass}/bin:$PATH

            # Prevent the gem from trying to download its own copy
            export SASS_EMBEDDED_DISABLE_VENDOR_DOWNLOAD=true

            echo "checking gems"
            bundle check || bundle install

            # Creating the user
            if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" | grep -q 1; then
              echo "Creating database user ${db_user}..."
              psql postgres -c "CREATE USER ${db_user} WITH SUPERUSER PASSWORD '${db_pass}';"
            fi
          '';
        };
      }
    );
}
