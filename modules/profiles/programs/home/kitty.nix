{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.kitty.enable {
    programs.kitty = {
      themeFile = "Catppuccin-Mocha";
      font = {
        name = "Maple Mono NF CN";
        size = 18;
      };
      settings = lib.mkMerge [
        {
          mouse_hide_wait = "-1.0";
          remember_window_size = "no";
          cursor_trail = "3";
          initial_window_width = "90c";
          initial_window_height = "26c";
          background_opacity = "0.92";
        }
        (lib.mkIf config.programs.fish.enable {
          shell = "${pkgs.fish}/bin/fish";
        })
      ];
      keybindings = {
        "ctrl+shift+enter" = "launch --cwd=current --copy-env --copy-cmdline";
        "ctrl+shift+alt+enter" = "launch --cwd=current";
        "ctrl+shift+q" = "close_window";
        "ctrl+shift+w" = "new_window";
      };
      extraConfig = ''
        mouse_map right press ungrabbed mouse_select_command_output
      '';
    };
  };
}
