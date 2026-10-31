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
      # Static QML validation only; no VM or behavior tests in flake checks.
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        quickshell =
          pkgs.runCommand "quickshell-lint"
            {
              nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
            }
            ''
              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              mkdir -p "$HOME" "$XDG_CACHE_HOME"
              qmllint \
                --import disable \
                --unqualified disable \
                --unused-imports disable \
                --uncreatable-type disable \
                -I ${pkgs.quickshell}/lib/qt-6/qml \
                -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
                ${../modules/profiles/de/quickshell/shell}/*.qml
              touch "$out"
            '';
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
