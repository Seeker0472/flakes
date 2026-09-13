{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  deCfg = lib.attrByPath [ "machine" "de" ] { } osConfig;
  niriEnabled = deCfg.niri.enable or false;

  focusOrSpawn = pkgs.writeShellApplication {
    name = "niri-focus-or-spawn";
    runtimeInputs = [
      pkgs.jq
      pkgs.niri
    ];
    text = ''
      if (( $# < 2 )); then
        echo "usage: niri-focus-or-spawn APP_ID_PATTERN COMMAND [ARG...]" >&2
        exit 2
      fi

      app_id_pattern="$1"
      shift

      windows="$(niri msg --json windows 2>/dev/null || printf '[]')"
      window_id="$(jq -r --arg pattern "$app_id_pattern" \
        '[.[] | select((.app_id // "") | test($pattern; "i"))][0].id // empty' \
        <<< "$windows" 2>/dev/null || true)"

      if [[ "$window_id" =~ ^[0-9]+$ ]]; then
        exec niri msg action focus-window --id "$window_id"
      fi

      exec "$@"
    '';
  };

  forceKill = pkgs.writeShellApplication {
    name = "niri-force-kill";
    runtimeInputs = [
      pkgs.jq
      pkgs.niri
    ];
    text = ''
      pid="$(niri msg --json focused-window 2>/dev/null | jq -r '.pid // empty' || true)"
      if [[ "$pid" =~ ^[0-9]+$ ]]; then
        kill -KILL "$pid"
      fi
    '';
  };

  resizeAndCenter = pkgs.writeShellApplication {
    name = "niri-resize-and-center";
    runtimeInputs = [ pkgs.niri ];
    text = ''
      niri msg action set-column-width "70%"
      niri msg action set-window-height "70%"
      niri msg action center-window
    '';
  };

  clipboardPicker = pkgs.writeShellApplication {
    name = "niri-clipboard-picker";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.fzf
      pkgs.wl-clipboard
    ];
    text = ''
      selection="$(
        cliphist list | fzf \
          --layout=reverse \
          --border=rounded \
          --info=inline \
          --no-multi \
          --prompt='Clipboard> '
      )" || exit 0

      [[ -n "$selection" ]] || exit 0
      printf '%s' "$selection" | cliphist decode | wl-copy
    '';
  };

  clipboardPickerTerminal = pkgs.writeShellApplication {
    name = "niri-clipboard-picker-terminal";
    runtimeInputs = [ pkgs.kitty ];
    text = ''
      exec kitty --class FG --title "Clipboard History" -e ${lib.getExe clipboardPicker}
    '';
  };

  mediaControl = pkgs.writeShellApplication {
    name = "niri-media-control";
    runtimeInputs = [ pkgs.wireplumber ];
    text = ''
      case "''${1:-}" in
        volume-up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
        volume-down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
        volume-mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
        microphone-mute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
        *) echo "usage: niri-media-control {volume-up|volume-down|volume-mute|microphone-mute}" >&2; exit 2 ;;
      esac
    '';
  };

  wallpaperQuote = import ../wallpaper-quote.nix { inherit pkgs; };

  monitor = (osConfig.machine.de.niri.monitor or { });
  initialMonitorConfig = pkgs.writeText "niri-monitor.kdl" (
    lib.optionalString (osConfig.machine.type == "laptop") ''
      output "${monitor.output or "eDP-1"}" {
          mode "${monitor.mode or "2560x1600"}"
          scale ${toString (monitor.scale or 1.333333)}
          position x=${toString (monitor.position.x or 0)} y=${toString (monitor.position.y or 0)}
      }
    ''
  );

  idle = import ../idle-common.nix { inherit lib pkgs; };
  lockCommand = idle.swaylockCommand;
  onBattery = idle.onBattery;

  niriConfig = pkgs.replaceVars ./config.kdl {
    focusOrSpawn = lib.getExe focusOrSpawn;
    forceKill = lib.getExe forceKill;
    clipboardPicker = lib.getExe clipboardPickerTerminal;
    mediaControl = lib.getExe mediaControl;
    nwgDisplays = lib.getExe pkgs.nwg-displays;
    resizeAndCenter = lib.getExe resizeAndCenter;
    wallpaperQuote = lib.getExe wallpaperQuote;
    brightnessctl = lib.getExe pkgs.brightnessctl;
    cliphist = lib.getExe pkgs.cliphist;
    kitty = lib.getExe pkgs.kitty;
    loginctl = "${pkgs.systemd}/bin/loginctl";
    playerctl = lib.getExe pkgs.playerctl;
    systemctl = "${pkgs.systemd}/bin/systemctl";
    thunar = lib.getExe pkgs.thunar;
    wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
    wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
    wpaperctl = "${pkgs.wpaperd}/bin/wpaperctl";
    xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
    quickshellStartup = lib.optionalString (deCfg.quickshell.enable or false) ''
      spawn-at-startup "${lib.getExe pkgs.quickshell}" "--config" "niri-shell"
    '';
    waybarStartup = lib.optionalString (deCfg.waybar.enable or false) ''
      spawn-at-startup "${lib.getExe pkgs.waybar}"
    '';
    quickshellToggle = lib.optionalString (deCfg.quickshell.enable or false) ''
      Mod+Shift+Space repeat=false hotkey-overlay-title="Toggle Control Center" { spawn "${lib.getExe pkgs.quickshell}" "ipc" "-c" "niri-shell" "call" "shell" "toggle"; }
    '';
    wpaperdStartup = lib.optionalString (deCfg.wpaperd.enable or false) ''
      spawn-at-startup "${lib.getExe pkgs.wpaperd}"
    '';
  };
in
{
  config = lib.mkIf niriEnabled {
    xdg.configFile."niri/config.kdl".source = niriConfig;

    # nwg-displays owns this writable include. Seed it only once so applying
    # Home Manager never overwrites a layout created from the GUI.
    home.activation.ensureNiriMonitorConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      monitor_config=${lib.escapeShellArg "${config.xdg.configHome}/niri/monitor.kdl"}
      if [[ ! -e "$monitor_config" && ! -L "$monitor_config" ]]; then
        run ${pkgs.coreutils}/bin/install -D -m 0644 ${initialMonitorConfig} "$monitor_config"
      fi
    '';

    home.packages = [
      pkgs.cliphist
      pkgs.nwg-displays
      pkgs.wl-clipboard
    ];

    programs.swaylock = {
      enable = true;
      package = idle.swaylockPackage;
      settings = {
        image = ../wallpaper/nix-wallpaper-moonscape.png;
        scaling = "fill";
        color = "303446ff";

        indicator = true;
        indicator-caps-lock = true;
        indicator-radius = 220;
        indicator-thickness = 13;

        clock = true;
        timestr = "%H:%M  ·  %m-%d";
        datestr = "󰌾  %A";
        font = "Maple Mono NF CN";
        font-size = 56;

        inside-color = "303446e6";
        inside-clear-color = "303446e6";
        inside-caps-lock-color = "303446e6";
        inside-ver-color = "303446e6";
        inside-wrong-color = "303446e6";
        ring-color = "ca9ee6ff";
        ring-clear-color = "e5c890ff";
        ring-caps-lock-color = "e5c890ff";
        ring-ver-color = "a6d189ff";
        ring-wrong-color = "e78284ff";
        line-color = "00000000";
        line-clear-color = "00000000";
        line-caps-lock-color = "00000000";
        line-ver-color = "00000000";
        line-wrong-color = "00000000";
        separator-color = "00000000";
        key-hl-color = "f4b8e4ff";
        bs-hl-color = "e78284ff";

        text-color = "c6d0f5ff";
        text-clear = "Enter password";
        text-clear-color = "c6d0f5ff";
        text-caps-lock = "Caps Lock";
        text-caps-lock-color = "e5c890ff";
        text-ver = "Authenticating...";
        text-ver-color = "a6d189ff";
        text-wrong = "Wrong password";
        text-wrong-color = "e78284ff";

        show-keyboard-layout = true;
        show-failed-attempts = true;
      };
    };

    services = {
      polkit-gnome.enable = true;

      swayidle = {
        enable = true;
        events = {
          before-sleep = lockCommand;
          lock = lockCommand;
        };
        timeouts = [
          {
            timeout = idle.timeouts.notify;
            command = "${onBattery} && ${idle.zzzNotify}";
          }
          {
            timeout = idle.timeouts.lock;
            command = "${onBattery} && ${idle.lockSession}";
          }
          {
            timeout = idle.timeouts.suspend;
            command = "${onBattery} && ${idle.suspendThenHibernate}";
          }
        ];
      };
    };
  };
}
