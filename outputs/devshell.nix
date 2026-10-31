{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
in
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      pre-commit.settings.hooks.nixfmt.enable = true;
      # qmllint/qmltestrunner only run on x86_64-linux, matching devContainerImage.
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        quickshell = import ../checks/quickshell.nix { inherit pkgs; };
        personal-storage = import ../checks/personal-storage.nix { inherit pkgs; };
      };
      formatter = pkgs.nixfmt-tree;
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.git
          pkgs.vim
          pkgs.neovim
          pkgs.nixfmt
          pkgs.sops
          pkgs.age
          pkgs.python3
          pkgs.qt6.qtdeclarative
        ];
        shellHook = config.pre-commit.shellHook;
      };
    };
}
