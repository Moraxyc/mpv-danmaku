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
        imports = [ inputs.flake-parts.flakeModules.easyOverlay ];

        systems = import inputs.systems;

        perSystem =
          {
            config,
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

              buildInputs = with pkgs; [ openssl ];

              nativeBuildInputs = with pkgs; [ pkg-config ];

              env.OPENSSL_NO_VENDOR = true;
            };

            cargoArtifacts = craneLib.buildDepsOnly commonArgs;

            scriptName = "danmaku${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
          in
          {
            overlayAttrs = { inherit (config.packages) mpv-danmaku; };
            packages = {
              mpv-danmaku = craneLib.buildPackage (
                commonArgs
                // {
                  inherit cargoArtifacts;
                  doCheck = true;

                  postInstall = ''
                    mkdir -p $out/share/mpv/scripts/
                    ln -sr $out/lib/libmpv_${scriptName} $out/share/mpv/scripts/${scriptName}
                  '';

                  passthru = {
                    inherit scriptName;
                  };

                  stripDebugList = [ "share/mpv/scripts" ];
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
