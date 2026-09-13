# Settings shared by all Wayland compositors (Hyprland / niri). NixOS-only.
# Imported by the compositor modules (hyprland/default.nix, niri/default.nix).
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
  imports = [ ./options.nix ];

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
