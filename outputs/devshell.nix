{ ... }:
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      pre-commit.settings.hooks.nixfmt.enable = true;
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
