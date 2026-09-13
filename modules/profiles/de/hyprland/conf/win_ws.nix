{
  lib,
  osConfig,
  ...
}:
let
  hyprlandEnabled = (import ../../enabled.nix lib osConfig);
in
{
  config = lib.mkIf hyprlandEnabled {
    wayland.windowManager.hyprland.settings = {
      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

      windowrule = [

        # Fcitx / Input
        "pin on,  match:initial_class (.*fcitx.*)"

      ];

      workspace = [
        "1, defaultName: 1, border:1, rounding:0, gapsin:0, gapsout:0, on-created-empty: [ ] kitty"
        "2, defaultName: 2, border:1, rounding:0, gapsin:0, gapsout:0, on-created-empty: [ ] kitty"
      ]
      ++ map (i: "${toString i}, defaultName:󰭠 ${toString i}") (lib.range 3 9)
      ++ [
        "200, defaultName:󰰷, on-created-empty: [ ] zen-beta"
      ];
    };
  };
}
