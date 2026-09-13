{
  pkgs,
  config,
  lib,
  ...
}:
lib.mkIf config.programs.fish.enable {
  programs.fish = {
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      # set theme_color_scheme zenburn
      # set theme_date_format +"%b/%e|%a %H:%M.%S"
      function fish_greeting; end
      set -g fish_key_bindings fish_vi_key_bindings
      # set -g VIRTUAL_ENV_DISABLE_PROMPT 1
    '';
    shellAliases = {
      nfp = "nix-shell --run fish -p";
      gd = "git difftool -d";
      nrs = "sudo nixos-rebuild switch";
    }
    // lib.optionalAttrs config.programs.kitty.enable {
      icat = "kitten icat";
      kssh = "kitten ssh";
      kmpv = "mpv --vo=kitty";
    };
    functions = {
      backup = ''
        set file $argv[1]
        if test -f "$file"
            set -l backup_name "$file"(date +'.%Y-%m-%d_%H-%M-%S')
            cp "$file" "$backup_name"
            echo "Backed up $file->$backup_name"
        else
            echo "Error: File not found - $file"
            return 1
        end
      '';
      # Restart a process via Hyprland; requires hyprctl (Hyprland session).
      rh = ''
        set -l process $argv[1]
        if not type -q hyprctl
            echo "rh: hyprctl not found; start '$process' manually"
            return 1
        end
        pkill "$process"
        echo "starting: $process"
        hyprctl dispatch exec "$process"
      '';
    };
    plugins = [
      {
        name = "z";
        src = pkgs.fishPlugins.z.src;
      } # fast cd into dir
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      } # TODO:LEARN!
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      } # Generic Recolouriser
      # { name = "fish-ysy"; src = pkgs.fishPlugins.fish-you-should-use.src; } # remind to use alies TODO:nix-ondroid don't work
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      } # notify
      # { name = "forgit"; src = pkgs.fishPlugins.forgit.src; }
      # { name = "cman"; src = pkgs.fishPlugins.colored-man-pages.src; } # no use
    ];
  };
  home.packages = [
    pkgs.fd # fzf-fish's dependence
    pkgs.grc
  ];
}
