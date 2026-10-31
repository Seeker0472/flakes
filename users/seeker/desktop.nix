{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ./xdg_default.nix
    ../../modules/home/desktop.nix
  ];

  home.packages = import ./packages/desktop.nix { inherit pkgs; };

  programs = {
    kitty.enable = true;
    zen-browser.enable = true;
  };
}
