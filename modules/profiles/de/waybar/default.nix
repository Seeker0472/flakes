{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = lib.attrByPath [
    "machine"
    "de"
  ] { } osConfig;
  ident = lib.attrByPath [
    "machine"
    "type"
  ] "others" osConfig;
  niriEnabled = cfg.niri.enable or false;
  killRTG = pkgs.writeShellScriptBin "kill-rtg" (
    if niriEnabled then
      ''
        ${pkgs.niri}/bin/niri msg --json windows | \
        ${pkgs.jq}/bin/jq -r '.[] | select(.app_id == "RTG") | .pid' | \
        ${pkgs.findutils}/bin/xargs -r kill -9
      ''
    else
      ''
        ${pkgs.hyprland}/bin/hyprctl clients -j | \
        ${pkgs.jq}/bin/jq -r '.[] | select(.class == "RTG") | .pid' | \
        ${pkgs.findutils}/bin/xargs -r kill -9
      ''
  );

  runInRTG =
    pkg: bin: args:
    "${killRTG}/bin/kill-rtg && ${pkgs.kitty}/bin/kitty -o font_size=14 -o confirm_os_window_close=0 --class RTG ${lib.getExe' pkg bin} ${args}";

  gotobedScript = pkgs.writeShellScriptBin "gotobed" ''
    start_hour=22
    end_hour=6

    current_hour=$(date +%H)

    if [[ "$current_hour" -ge "$start_hour" || "$current_hour" -lt "$end_hour" ]]; then
      # class 可以用来在 style.css 中定义不同的样式
      echo '{"text": "󰋣  !", "tooltip": "", "class": "bedtime"}'
    else
      echo '{}'
    fi
    exit 0
  '';
in
{
  config = lib.mkIf (cfg.waybar.enable or false) {
    xdg.configFile."waybar/style.css".source = ./style.css;

    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 32;

          modules-left =
            if niriEnabled then
              [
                "niri/workspaces"
                "niri/window"
              ]
            else
              [
                "hyprland/workspaces"
                "hyprland/window"
              ];
          # modules-center = [ "custom/lrc" ];
          modules-right = [
            "custom/gotobed"
            "group/sysinfo"
            "group/control"
            "idle_inhibitor"
            "privacy"
            "pulseaudio"
            "clock"
            "tray"
          ];

          "group/sysinfo" = {
            orientation = "inherit";
            drawer = {
              transition-duration = 220;
              transition-left-to-right = false;
            };
            modules = (lib.optional (ident == "laptop") "battery") ++ [
              "temperature"
              "cpu"
              "memory"
            ];
          };

          "group/control" = {
            orientation = "inherit";
            drawer = {
              transition-duration = 220;
              transition-left-to-right = false;
            };
            modules = [
              "network"
              "custom/wallpaper"
              "bluetooth"
              "cava"
            ]
            ++ (lib.optional (ident == "laptop") "backlight");
          };

          "niri/workspaces" = {
            format = "{index}";
          };

          "idle_inhibitor" = {
            format = "{icon}";
            format-icons = {
              activated = "";
              deactivated = "";
            };
          };

          "privacy" = {
            modules = [
              { type = "screenshare"; }
              { type = "audio-in"; }
            ];
            ignore = [
              {
                type = "audio-in";
                name = "cava";
              }
            ];
          };

          "network" = {
            # interface = "wlp2*"; # (Optional) To force the use of this interface
            format-wifi = " {signalStrength}%";
            format-ethernet = "";
            tooltip-format = "{ifname} via {gwaddr} 󰩠 {ipaddr}";
            format-linked = "󰛵";
            format-disconnected = "";
            format-alt = "{ifname}: {ipaddr}/{cidr}";
            on-click-right = runInRTG pkgs.networkmanager "nmtui-connect" "";
          };

          "cpu" = {
            states = {
              warning = 50;
              high = 80;
            };
            format = "{usage}%  ";
            on-click-right = runInRTG pkgs.btop "btop" "";
          };

          "memory" = {
            states = {
              warning = 50;
              high = 80;
            };
            format = "{}%  ";
            tooltip-format = ''
              {used:0.1f}/{total:0.1f}GiB Mem
              {swapUsed:0.1f}/{swapTotal:0.1f}GiB Swap'';
            on-click-right = runInRTG pkgs.btop "btop" "";
          };

          "pulseaudio" = {
            scroll-step = 1;
            format = "{volume}% {icon}";
            format-alt = "{format_source}";
            format-bluetooth = "{volume}% {icon} {format_source}";
            format-bluetooth-muted = "  {icon} {format_source}";
            format-muted = "  {format_source}";
            format-source = "{volume}% ";
            format-source-muted = " ";
            format-icons = {
              headphone = " ";
              hands-free = " ";
              headset = "󰋌 ";
              phone = " ";
              ${
                lib.attrByPath [
                  "machine"
                  "de"
                  "waybar"
                  "internalAudioSink"
                ] "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink" osConfig
              } =
                [
                  "  "
                  "  "
                  "  "
                ];
              default = [
                "  "
                "  "
                "  "
              ];
            };
            on-click-right = lib.getExe pkgs.pavucontrol;
          };

          "bluetooth" = {
            format = " {status}";
            format-connected = " {num_connections}";
            format-alt = " {device_alias}";
            # format-connected-battery = " {device_alias} {device_battery_percentage}%";
            # format-device-preference = [ "device1" "device2" ]; # preference list deciding the displayed device
            tooltip-format = ''
              {controller_alias}	{controller_address}

              {num_connections} connected'';
            tooltip-format-connected = ''
              {controller_alias}	{controller_address}

              {num_connections} connected

              {device_enumerate}'';
            tooltip-format-enumerate-connected = "{device_alias}	{device_address}";
            tooltip-format-enumerate-connected-battery = "{device_alias}	{device_address}	{device_battery_percentage}%";
            on-click-right = runInRTG pkgs.bluetuith "bluetuith" "";
          };

          "clock" = {
            # timezone = "America/New_York";
            tooltip-format = ''
              <big>{:%Y %B}</big>
              <tt><small>{calendar}</small></tt>'';
            format-alt = "{:%Y-%m-%d}";
            on-click-right = runInRTG pkgs.neovim "nvim" "${config.home.homeDirectory}/Documents/todo.md";
          };

          "custom/gotobed" = {
            format = "{}";
            return-type = "json";
            interval = 60;
            exec = lib.getExe gotobedScript;
          };

          "custom/wallpaper" = {
            format = "󰸉 ";
            on-click = "${pkgs.wpaperd}/bin/wpaperctl next-wallpaper";
          };

          # 电池与亮度模块 (仅在需要时配置)
          "battery" = {
            states = {
              warning = 40;
              critical = 15;
            };
            format = "{capacity}% {icon}";
            format-full = "{capacity}% {icon}";
            format-charging = "{capacity}% 󰂄";
            format-plugged = "{capacity}% ";
            format-alt = "{time} {icon}";
            format-icons = [
              " "
              " "
              " "
              " "
              " "
            ];
          };
          "backlight" = {
            format = "{percent}% {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
          };
          "temperature" = {
            # thermal-zone = 2;
            # hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
            critical-threshold = 80;
            # format-critical = "{temperatureC}°C {icon}";
            format = "{temperatureC}°C {icon}";
            format-icons = [
              ""
              " "
            ];
          };
          "tray" = {
            spacing = 5;
          };

          "cava" = {
            framerate = 20;
            autosens = 1;
            sensitivity = 5;
            bars = 10;
            lower_cutoff_freq = 100;
            higher_cutoff_freq = 1000;
            method = "pulse";
            source = "auto";
            stereo = true;
            reverse = false;
            bar_delimiter = 0;
            monstercat = false;
            waves = false;
            noise_reduction = 0.77;
            input_delay = 2;
            format-icons = [
              "▁"
              "▂"
              "▃"
              "▄"
              "▅"
              "▆"
              "▇"
              "█"
            ];
            actions = {
              on-click-right = "mode";
            };
          };
        };
      };
    };
  };
}
