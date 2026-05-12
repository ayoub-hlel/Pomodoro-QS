{
  description = "Pomodoro-QS Dev Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacy.import { inherit system; };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              quickshell
              gcalcli
              # Add other dependencies from Available Tools.md as needed
              ddcutil
              brightnessctl
              libcava
              playerctl
            ];
          };
        };
      }
    );
}
