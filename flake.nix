{
  description = "Zig project flake";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
    zls.url = "github:zigtools/zls?ref=0.14.0";

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      zig2nix,
      zls,
      treefmt-nix,
      ...
    }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        # Zig flake helper
        # Check the flake.nix in zig2nix project for more options:
        # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
        env = zig2nix.outputs.zig-env.${system} {
          zig = zig2nix.outputs.packages.${system}.zig-latest;
        };

        # zlsPkg = zls.packages.${system}.default;
        zlsPkg = env.pkgs.zls;
        treefmtEval = treefmt-nix.lib.evalModule env.pkgs ./treefmt.nix;
        zigimportsPkg = env.pkgs.zigimports;

        nativeBuildInputs = with env.pkgs; [ ];

        buildInputs = with env.pkgs; [ ];
      in
      with builtins;
      with env.pkgs.lib;
      rec {
        # Produces clean binaries meant to be ship'd outside of nix
        # nix build .#foreign
        packages.foreign = env.package {
          src = cleanSource ./.;

          # Packages required for compiling
          nativeBuildInputs = nativeBuildInputs;

          # Packages required for linking
          buildInputs = buildInputs;

          # Smaller binaries and avoids shipping glibc.
          zigPreferMusl = true;
        };

        # nix build .
        packages.default = packages.foreign.override (attrs: {
          # Prefer nix friendly settings.
          zigPreferMusl = false;

          # Executables required for runtime
          # These packages will be added to the PATH
          zigWrapperBins = [ ];

          # Libraries required for runtime
          # These packages will be added to the LD_LIBRARY_PATH
          zigWrapperLibs = buildInputs;
        });

        # For bundling with nix bundle for running outside of nix
        # example: https://github.com/ralismark/nix-appimage
        apps.bundle = {
          type = "app";
          program = "${packages.foreign}/bin/base64";
        };

        # nix run .
        apps.default = {
          type = "app";
          program = "${packages.default}/bin/base64";
        };

        # nix run .#build
        apps.build = env.app [ ] "zig build \"$@\"";

        # nix run .#test
        apps.test = env.app [ ] "zig build test -- \"$@\"";

        # nix run .#zig2nix
        apps.zig2nix = env.app [ ] "zig2nix \"$@\"";

        formatter = treefmtEval.config.build.wrapper;

        # nix develop
        devShells.default = env.mkShell {
          # Packages required for compiling, linking and running
          # Libraries added here will be automatically added to the LD_LIBRARY_PATH and PKG_CONFIG_PATH
          nativeBuildInputs =
            [
              zlsPkg
              zigimportsPkg
            ]
            ++ nativeBuildInputs
            ++ buildInputs;
        };
      }
    ));
}
