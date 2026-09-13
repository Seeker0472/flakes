{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  impermanenceEnabled = lib.attrByPath [ "machine" "impermanence" "enable" ] false osConfig;
  persistDir = lib.attrByPath [ "machine" "btrfs" "impermanence" "persistdir" ] null osConfig;
  hyprlandEnabled = lib.attrByPath [ "machine" "de" "hyprland" "enable" ] false osConfig;
  niriEnabled = lib.attrByPath [ "machine" "de" "niri" "enable" ] false osConfig;
  lockCommand =
    if niriEnabled then
      "${pkgs.systemd}/bin/loginctl lock-session"
    else
      "${pkgs.hyprlock}/bin/hyprlock";
in
{
  imports = [
    ./desktop.nix
    ./ssh-secrets.nix
    ./taskwarrior-sync.nix
  ];

  config = lib.mkMerge [
    {
      programs.aloha = {
        enable = true;
        package = inputs.aloha.packages.${pkgs.stdenv.hostPlatform.system}.default;
        kitty = {
          title = "Aloha";
          class = "AlohaLauncher";
        };
        fzf.extraOptions = [
          "--layout=reverse"
          "--height=60%"
        ];
        roots = {
          apps = {
            prompt = "Apps> ";
            sources = [ { type = "desktop"; } ];
          };
          commands = {
            prompt = "Commands> ";
            sources = [
              {
                type = "static";
                items = [
                  {
                    id = "command-terminal";
                    label = "Terminal";
                    action = "exec";
                    command = "${pkgs.kitty}/bin/kitty";
                  }
                ]
                ++ lib.optionals hyprlandEnabled [
                  {
                    id = "command-display-settings";
                    label = "Display Settings";
                    action = "exec";
                    command = "${pkgs.nwg-displays}/bin/nwg-displays";
                  }
                ]
                ++ lib.optionals niriEnabled [
                  {
                    id = "command-display-settings";
                    label = "Display Status";
                    action = "exec";
                    command = "${pkgs.kitty}/bin/kitty --class RTG --hold ${pkgs.niri}/bin/niri msg outputs";
                  }
                  {
                    id = "command-cast-focused-window";
                    label = "Cast Focused Window";
                    action = "exec";
                    command = "${pkgs.niri}/bin/niri msg action set-dynamic-cast-window";
                  }
                  {
                    id = "command-cast-focused-monitor";
                    label = "Cast Focused Monitor";
                    action = "exec";
                    command = "${pkgs.niri}/bin/niri msg action set-dynamic-cast-monitor";
                  }
                  {
                    id = "command-clear-dynamic-cast";
                    label = "Clear Dynamic Cast Target";
                    action = "exec";
                    command = "${pkgs.niri}/bin/niri msg action clear-dynamic-cast-target";
                  }
                ]
                ++ [
                  {
                    id = "command-next-wallpaper";
                    label = "Next Wallpaper";
                    action = "exec";
                    command = "${pkgs.wpaperd}/bin/wpaperctl next-wallpaper";
                  }
                ]
                ++ lib.optionals hyprlandEnabled [
                  {
                    id = "command-reload-hyprland";
                    label = "Reload Hyprland";
                    action = "exec";
                    command = "${pkgs.hyprland}/bin/hyprctl reload";
                  }
                ]
                ++ lib.optionals niriEnabled [
                  {
                    id = "command-reload-niri";
                    label = "Reload Niri";
                    action = "exec";
                    command = "${pkgs.niri}/bin/niri msg action load-config-file --path ${config.home.homeDirectory}/.config/niri/config.kdl";
                  }
                ]
                ++ [
                  {
                    id = "command-brightness";
                    label = "Brightness";
                    action = "provider-submenu";
                    provider = "brightness";
                    providerArgs.levels = [
                      10
                      25
                      50
                      75
                      100
                    ];
                  }
                ];
              }
            ];
          };
          power = {
            prompt = "Power> ";
            sources = [
              {
                type = "static";
                items = [
                  {
                    id = "power-lock";
                    label = "Lock";
                    action = "exec";
                    command = lockCommand;
                  }
                  {
                    id = "power-poweroff";
                    label = "Poweroff";
                    action = "builtin-action";
                    builtin = "poweroff";
                  }
                  {
                    id = "power-reboot";
                    label = "Reboot";
                    action = "builtin-action";
                    builtin = "reboot";
                  }
                  {
                    id = "power-suspend";
                    label = "Suspend";
                    action = "builtin-action";
                    builtin = "suspend";
                  }
                  {
                    id = "power-hibernate";
                    label = "Hibernate";
                    action = "builtin-action";
                    builtin = "hibernate";
                  }
                  {
                    id = "power-suspend-then-hibernate";
                    label = "Suspend Then Hibernate";
                    action = "builtin-action";
                    builtin = "suspend-then-hibernate";
                  }
                ];
              }
            ];
          };
        };
      };

    }

    (lib.mkIf hyprlandEnabled {
      wayland.windowManager.hyprland.settings = {
        "$menu" = lib.mkForce "aloha --root apps";
        bind = lib.mkAfter [
          "$mainMod, P, exec, aloha --root commands"
          "$mainMod SHIFT, P, exec, aloha --root power"
        ];
        bindl = lib.mkAfter [
          '', switch:off:Lid Switch, execr, [ $(hyprctl monitors | grep -c "eDP-1") -ne 1 ] && hyprctl keyword monitor eDP-1,2560x1600@120.0,0x237,1.33''
          '', switch:on:Lid Switch, execr, [ $(hyprctl monitors | grep -c "ID") -ne 1 ] && hyprctl keyword monitor eDP-1,disable''
        ];
        windowrule = lib.mkAfter [
          "tag +aloha_launcher, match:initial_class ^(AlohaLauncher)$"
          "float on, match:tag aloha_launcher*"
          "center on, match:tag aloha_launcher*"
          "size (monitor_w*0.7) (monitor_h*0.6), match:tag aloha_launcher*"
        ];
      };
    })

    (lib.mkIf (impermanenceEnabled && persistDir != null) {
      home.persistence."${persistDir}" = {
        directories = [
          "Downloads"
          "Documents"
          "Pictures"
          "Videos"
          {
            directory = ".docker";
            mode = "0700";
          }
          ".ssh"
          ".gnupg"
          ".factorio"
          ".local/share/fish"
          ".local/share/direnv"
          ".local/share/fcitx5"
          # Zellij stores plugin permission grants in this cache.
          ".cache/zellij"
          ".cache/cliphist"
          ".config/fcitx5"
          ".config/dconf"
          ".config/hypr"
          ".config/niri"
          ".local/share/hyprland"
          ".local/state/nvim"
          ".local/state/wireplumber"
          ".local/state/yazi"
          ".local/state/aloha"
          ".config/kdeconnect"
          ".config/obsidian"
          ".vscode"
          ".config/Code"
          ".local/share/keyrings"
          ".local/share/task"
          ".local/share/zed"
          ".config/zen"
          "VirtualBox VMs"
          ".zotero"
          "Zotero"
        ];
        files = [
          ".gtkwaverc"
          ".local/bin/bitlesson-selector"
        ];
      };
    })
  ];
}
