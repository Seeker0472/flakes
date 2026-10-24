# Shared runtime policy for the Wayland desktops, including legacy nix-shell.
{ config, lib, ... }:
let
  cfg = config.machine.de;
in
{
  config = lib.mkIf (cfg.hyprland.enable || cfg.niri.enable) {
    # AWT applications with their own X11-only JVM still need this on tiling WMs.
    environment.sessionVariables._JAVA_AWT_WM_NONREPARENTING = "1";

    nixpkgs.overlays = [ (import ./java-overlay.nix) ];

    # nix-shell -p imports nixpkgs independently of the NixOS package set.
    # Share just this overlay; do not re-evaluate the whole NixOS configuration.
    home-manager.sharedModules = [
      {
        xdg.configFile."nixpkgs/overlays/java-wayland.nix".source = ./java-overlay.nix;
      }
    ];
  };
}
