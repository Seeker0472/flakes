# Settings shared by all Wayland compositors (Hyprland / niri). NixOS-only.
# Shared integration for the compositor profiles in the desktop bundle.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.machine.de;
  compositorEnabled = cfg.hyprland.enable || cfg.niri.enable;
in
{
  imports = [
    ./options.nix
    ./java.nix
  ];

  config = lib.mkIf compositorEnabled {
    services.displayManager = {
      gdm.enable = true;
      defaultSession = if cfg.niri.enable then "niri" else "hyprland";
    };
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = [
      pkgs.libnotify
      pkgs.acpi
    ];
  };
}
