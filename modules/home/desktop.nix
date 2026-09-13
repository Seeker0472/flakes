{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  customCursor = {
    name = "Bibata-Modern-Amber";
    package = pkgs.bibata-cursors;
    size = 32;
  };
  deCfg = osConfig.machine.de;
  notificationDaemon = deCfg.notificationDaemon;
  compositorEnabled = deCfg.hyprland.enable || deCfg.niri.enable;

  # kitty --class values for the floating / global / right-top terminal
  # instances, matched exactly by the windowrules below.
  kittyClass = {
    floatTerm = "FG";
    globalTerm = "GT";
    rightTopTerm = "RT";
  };
in
{
  imports = [
    # Declares machine.de options on the Home Manager side so osConfig reads
    # type-check instead of relying on attribute fallbacks.
    ../profiles/de/options.nix
    ../profiles/de/config-files.nix
    ../profiles/de/quickshell/default.nix
    ../profiles/de/waybar/default.nix
    ../profiles/de/niri/home.nix
    ../profiles/de/hyprland/conf/appearance.nix
    ../profiles/de/hyprland/conf/hyprland.nix
    ../profiles/de/hyprland/conf/input.nix
    ../profiles/de/hyprland/conf/keybind.nix
    ../profiles/de/hyprland/conf/win_ws.nix
    ../profiles/de/hyprland/conf/hypridle.nix
    ../profiles/de/hyprland/conf/autostart.nix
    ../profiles/input/fcitx5.nix
    ../profiles/programs/home/kitty.nix
    ../profiles/programs/home/zed.nix
    ./kde-connect.nix
    ./thunar.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf deCfg.hyprland.enable {
      wayland.windowManager.hyprland = {
        enable = true;
        settings = {
          "$terminal" = "${pkgs.kitty}/bin/kitty";
          "$floatTerminal" = "${pkgs.kitty}/bin/kitty --class ${kittyClass.floatTerm}";
          exec-once = [
            "hyprctl setcursor ${customCursor.name} ${builtins.toString customCursor.size}"
          ];
          windowrule = [
            "tag +float_term, match:initial_class (${kittyClass.floatTerm}), match:initial_title ^(kitty)$"
            "float on, match:tag float_term*"
            "center on, match:tag float_term*"
            "size (monitor_w*0.7) (monitor_h*0.7), match:tag float_term*"
            "tag +global_term, match:initial_class (${kittyClass.globalTerm}), match:initial_title ^(kitty)$"
            "pin on, match:tag global_term*"
            "tag +right_top_term, match:initial_class (${kittyClass.rightTopTerm}), match:initial_title ^(kitty)$"
            "size (monitor_w*0.6) (monitor_h*0.7), match:tag right_top_term*"
            "float on, match:tag right_top_term*"
            "move (monitor_w-window_w) 30, match:tag right_top_term*"
            "tag +qq_pic, match:initial_class ^(QQ)$, match:initial_title ^(图片查看器)$"
            "size (monitor_w*0.7) (monitor_h*0.7), match:tag qq_pic*"
            "float on, match:tag qq_pic*"
            "center on, match:tag qq_pic*"
            "workspace special:qq, match:class ^(QQ)$"
            "workspace special:music, match:class (com.gitee.gmg137.NeteaseCloudMusicGtk4)"
            "workspace special:obsidian, match:class (obsidian)"
            "workspace special:zed, match:class (dev.zed.Zed)"
            "workspace special:zotero, match:class (Zotero)"
          ];
          workspace = [
            "special:qq, on-created-empty: [ ] qq"
            "special:music, on-created-empty: [ ] netease-cloud-music-gtk4"
            "special:obsidian, on-created-empty: [ ] obsidian"
            "special:zed, on-created-empty: [ ] zeditor"
            "special:zotero, on-created-empty: [ ] zotero"
            "201, defaultName:󰨞, on-created-empty: [ ] code"
          ];
          bind = [
            "$mainMod, Q, togglespecialworkspace, qq"
            "$mainMod, 0, togglespecialworkspace, qq"
            "$mainMod CONTROL, C, exec, sh -c 'wl-paste --primary --no-newline | wl-copy'"
            "$mainMod, N, togglespecialworkspace, music"
            "$mainMod, O, togglespecialworkspace, obsidian"
            "$mainMod, D, togglespecialworkspace, obsidian"
            "$mainMod, X, togglespecialworkspace, zed"
            "$mainMod, Z, togglespecialworkspace, zotero"
            "$mainMod, V, workspace, 201"
          ];
        };
      };
    })

    (lib.mkIf compositorEnabled {
      home.pointerCursor = {
        enable = true;
        inherit (customCursor) name package size;
        gtk.enable = true;
        x11.enable = true;
      };

      gtk = {
        enable = true;
        theme = {
          package = pkgs.kdePackages.breeze-gtk;
          name = "Breeze";
        };
        iconTheme = {
          package = pkgs.kdePackages.breeze-icons;
          name = "breeze";
        };
        gtk4.theme = config.gtk.theme;
      };

      services.mako = lib.mkIf (notificationDaemon == "mako") {
        enable = true;
      };

      services.swaync = lib.mkIf (notificationDaemon == "swaync") {
        enable = true;
        package = pkgs.swaynotificationcenter.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ../profiles/de/swaync/long-notifications.patch ];
        });
        settings = {
          positionX = "right";
          positionY = "top";
          layer = "overlay";
          layer-shell = true;
          layer-shell-cover-screen = true;
          cssPriority = "user";
          notification-window-width = 520;
          notification-window-height = -1;
          timeout = 24;
          timeout-low = 24;
          timeout-critical = 0;
          notification-grouping = true;
          image-visibility = "when-available";
          transition-time = 220;
          control-center-positionX = "none";
          control-center-positionY = "none";
        };
        style = ../profiles/de/swaync/style.css;
      };
    })
  ];
}
