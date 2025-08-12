{
  description = "Ruby 3.2.2 development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
        pkgs = nixpkgs.legacyPackages.${system};

        db_user = "esm";
        db_pass = "password12345";
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (ruby_3_2.override {
              jemallocSupport = false;
              docSupport = false;
            })

            # Dependencies for native gems
            pkg-config
            openssl
            readline
            zstd
            libyaml

            # DB dependencies
            postgresql_15
            redis
            mysql80
          ];

          shellHook = ''
            export GEM_HOME="$PWD/vendor/bundle"
            export GEM_PATH="$GEM_HOME"
            export PATH="$GEM_HOME/bin:$PATH"

            export RUBYOPT="-W:no-deprecated -W:no-experimental -ruri"
            export PRINT_LOG='true'
            export ESM_ENV='development'

            # Creating the user
            if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" | grep -q 1; then
              echo "creating database user ${db_user}..."
              psql postgres -c "CREATE USER ${db_user} WITH SUPERUSER PASSWORD '${db_pass}';"
            fi

            echo "checking gems"
            bundle check || bundle install
          '';
        };
      }
    );
}
