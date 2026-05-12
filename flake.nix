{
  description = "Pomodoro-QS — Native Caelestia Shell Integration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    caelestia-shell.url = "github:caelestia-dots/shell";
    # Ensure dependencies match system-wide versions
    caelestia-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, caelestia-shell }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "pomodoro-qs";
          version = "1.0.0";
          src = ./.;

          # This is a placeholder for the actual patching logic which will be refined later.
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            caelestia-shell.packages.${system}.default
            quickshell
            gcalcli
            sqlite
          ];

          shellHook = ''
            export QML_IMPORT_PATH=$QML_IMPORT_PATH:${./.}
            echo "🍎 Pomodoro-QS Development Shell"
          '';
        };
      }
    );
}
