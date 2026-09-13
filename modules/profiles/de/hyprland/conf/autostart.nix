{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  hyprlandEnabled = (import ../../enabled.nix lib osConfig);
  waybarEnabled = lib.attrByPath [
    "machine"
    "de"
    "waybar"
    "enable"
  ] false osConfig;
  wpaperdEnabled = lib.attrByPath [
    "machine"
    "de"
    "wpaperd"
    "enable"
  ] false osConfig;
in
{
  config = lib.mkIf hyprlandEnabled {
    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # TODO: fix these two services
        "systemctl --user restart xdg-desktop-portal.service"
        "systemctl --user restart xdg-desktop-portal-hyprland.service"
        # Fcitx5 starts through its XDG autostart entry.
      ]
      ++ lib.lists.optional wpaperdEnabled "${pkgs.wpaperd}/bin/wpaperd"
      ++ [
        "systemctl --user start ${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent" # polkit agent (root permission)
        "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
        # "ydotoold"
      ]
      ++ lib.lists.optional waybarEnabled "${pkgs.waybar}/bin/waybar";
    };
  };
}
