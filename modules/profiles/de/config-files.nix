{
  lib,
  osConfig,
  ...
}:
let
  cfg = lib.attrByPath [
    "machine"
    "de"
  ] { } osConfig;
  compositorEnabled = (cfg.hyprland.enable or false) || (cfg.niri.enable or false);
in
{
  config = lib.mkIf compositorEnabled {
    xdg.configFile = lib.mkMerge [
      (lib.mkIf (cfg.wofi.enable or false) {
        "wofi".source = ./wofi;
      })
      (lib.mkIf ((cfg.notificationDaemon or "swaync") == "mako") {
        "mako".source = ./mako;
      })
      (lib.mkIf (cfg.wpaperd.enable or false) {
        "wpaperd".source = ./wpaperd;
      })
    ];

    home.file."Pictures/wallpaper/default".source = ./wallpaper;
  };
}
