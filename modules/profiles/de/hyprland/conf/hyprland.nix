{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  hyprlandEnabled = (import ../../enabled.nix lib osConfig);
  wofiEnabled = lib.attrByPath [
    "machine"
    "de"
    "wofi"
    "enable"
  ] false osConfig;
in
{
  config = lib.mkIf hyprlandEnabled {
    home.packages = [ pkgs.nwg-displays ]; # set display for hyprland
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "hyprlang";
      systemd.enable = true;
      extraConfig = ''
        # source the nwg-displays generated config
        source = ./monitors.conf
      '';
      settings =
        lib.optionalAttrs wofiEnabled {
          "$menu" = "wofi --show drun -a";
        }
        // {
          env = [
            "QT_QPA_PLATFORM,wayland;xcb"
            "QT_IM_MODULE,fcitx"
          ];

          xwayland = {
            force_zero_scaling = true;
          };
        };
    };
  };
}
