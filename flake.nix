{
  description = "mpv-danmaku development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      {
        systems = import inputs.systems;

        perSystem =
          {
            pkgs,
            self',
            ...
          }:
          let
            craneLib = inputs.crane.mkLib pkgs;

            src = craneLib.cleanCargoSource ./.;

            commonArgs = {
              inherit src;
              strictDeps = true;

              buildInputs = with pkgs; [ openssl ] ++ lib.optionals stdenv.isDarwin [ libiconv ];

              nativeBuildInputs = with pkgs; [ pkg-config ];

              env.OPENSSL_NO_VENDOR = true;
            };

            cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          in
          {
            packages = {
              mpv-danmaku = craneLib.buildPackage (
                commonArgs
                // {
                  inherit cargoArtifacts;
                  doCheck = true;

                  postInstall = ''
                    mkdir -p $out/share/mpv/scripts/
                    ln -sr $out/lib/libmpv_danmaku.so $out/share/mpv/scripts/danmaku.so
                  '';

                  stripDebugList = [ "share/mpv/scripts" ];
                  passthru.scriptName = "danmaku.so";
                }
              );
              default = self'.packages.mpv-danmaku;
            };

            checks = {
              inherit (self'.packages) mpv-danmaku;

              clippy = craneLib.cargoClippy (
                commonArgs
                // {
                  inherit cargoArtifacts;
                  cargoClippyExtraArgs = "--all-targets -- --deny warnings";
                }
              );

              fmt = craneLib.cargoFmt {
                inherit src;
              };

              audit = craneLib.cargoAudit {
                inherit src;
                advisory-db = inputs.advisory-db;
              };
            };

            devShells.default = craneLib.devShell {
              inherit (self') checks;

              packages = with pkgs; [ rust-analyzer ];

              env.OPENSSL_NO_VENDOR = true;
            };
          };
      }
    );
}
