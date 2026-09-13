{
  lib,
  osConfig,
  ...
}:
{
  # These rules only target Hyprland; Hyprland's own enablement is already
  # covered by desktop.nix, so only the thunar flag is needed here.
  config = lib.mkIf osConfig.machine.programs.thunar.enable {
    wayland.windowManager.hyprland.settings = {
      "$fileManager" = "thunar";
      windowrule = [
        "tag +thunar, match:class (thunar)"
        "float on, match:tag thunar*"
        "center on, match:tag thunar*"
        "size (monitor_w*0.7) (monitor_h*0.7), match:tag thunar*"
        "size (monitor_w*0.5) (monitor_h*0.5), match:tag thunar*,match:title ^(File Operation Progress)$"
        "size (monitor_w*0.5) (monitor_h*0.5), match:tag thunar*,match:title (.*Properties)"
      ];
      bind = [
        "$mainMod, E, exec, $fileManager"
      ];
    };
  };
}
