# Declares the machine.de option tree (shared by the NixOS and Home Manager
# module systems). NixOS-only activation lives in ./common.nix.
{
  config,
  lib,
  ...
}:
let
  cfg = config.machine.de;
  compositorEnabled = cfg.hyprland.enable || cfg.niri.enable;
in
{
  options.machine.de = {
    hyprland.enable = lib.mkEnableOption "Hyprland, a dynamic tiling Wayland compositor that doesn't sacrifice on looks";
    niri = {
      enable = lib.mkEnableOption "niri, a scrollable-tiling Wayland compositor";
      monitor = {
        output = lib.mkOption {
          type = lib.types.str;
          default = "eDP-1";
          description = "Name of the internal monitor to configure in the seeded niri monitor.kdl (laptop only)";
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "2560x1600";
          description = "Mode (resolution) of the internal monitor in the seeded niri monitor.kdl";
        };
        scale = lib.mkOption {
          type = lib.types.float;
          default = 1.333333;
          description = "Scale factor of the internal monitor in the seeded niri monitor.kdl";
        };
        position = {
          x = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "X position of the internal monitor in the seeded niri monitor.kdl";
          };
          y = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Y position of the internal monitor in the seeded niri monitor.kdl";
          };
        };
      };
    };
    quickshell.enable = lib.mkEnableOption "Quickshell, the Niri desktop shell and control center";
    waybar.enable = lib.mkOption {
      type = lib.types.bool;
      default = !cfg.quickshell.enable;
      description = "Waybar, a highly customizable Wayland bar (disabled by default when Quickshell is enabled)";
    };
    wofi.enable = lib.mkEnableOption "wofi, a launcher and menu program for Wayland compositors";
    notificationDaemon = lib.mkOption {
      type = lib.types.enum [
        "mako"
        "swaync"
      ];
      default = "swaync";
      description = "Notification daemon used by the Wayland desktop";
    };
    wpaperd.enable = lib.mkEnableOption "wpaperd, a modern wallpaper daemon for Wayland";
    waybar.internalAudioSink = lib.mkOption {
      type = lib.types.str;
      default = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";
      description = "PulseAudio sink name of the internal speakers, used for laptop volume icons in Waybar";
    };
  };
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.hyprland.enable && cfg.niri.enable);
          message = "machine.de.hyprland and machine.de.niri cannot be enabled at the same time";
        }
        {
          assertion = !cfg.quickshell.enable || cfg.niri.enable;
          message = "machine.de.quickshell.enable requires machine.de.niri.enable";
        }
      ];
    }
    (lib.mkIf compositorEnabled {
      machine.de = {
        quickshell.enable = lib.mkDefault cfg.niri.enable;
        wofi.enable = lib.mkDefault true;
        wpaperd.enable = lib.mkDefault true;
      };
    })
  ];
}
