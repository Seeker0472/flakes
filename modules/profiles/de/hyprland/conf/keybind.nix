{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  hyprlandEnabled = (import ../../enabled.nix lib osConfig);
  slurp = "${pkgs.slurp}/bin/slurp";
  grim = "${pkgs.grim}/bin/grim";
  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
  notify-send = "${pkgs.libnotify}/bin/notify-send";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  rm = "${pkgs.coreutils}/bin/rm";
  mkdir = "${pkgs.coreutils}/bin/mkdir";
  mktemp = "${pkgs.coreutils}/bin/mktemp";

  screenshootScript = pkgs.writeShellScriptBin "screenshoot" ''
    SHOT_DIR=/tmp/screenshots
    ${mkdir} -p "$SHOT_DIR"
    TMP_FILE=$(${mktemp} "$SHOT_DIR/screenshot-XXXXXX.png")

    GEOMETRY=$(${slurp})

    # Check whether canceled
    if [ $? -ne 0 ] || [ -z "$GEOMETRY" ]; then
        ${rm} -f "$TMP_FILE"
        ${notify-send} -u low "Screenshot Cancelled"
        exit 1
    fi

    # screenshoot && copy && notify
    if ${grim} -g "$GEOMETRY" "$TMP_FILE"; then
        ${wl-copy} --type image/png < "$TMP_FILE"
        ${notify-send} "Area Screenshot Taken" "Screenshot copied to clipboard,click to edit." --icon="$TMP_FILE" --category=screenshoot
        exit 0
    else
        ${rm} -f "$TMP_FILE"
        ${notify-send} -u critical "Screenshot Failed" "Could not capture screen area."
        exit 1
    fi
  '';
  wallpaperQuote = import ../../wallpaper-quote.nix { inherit pkgs; };
in
{
  config = lib.mkIf hyprlandEnabled {
    wayland.windowManager.hyprland.settings = {
      "$mainMod" = "SUPER"; # Sets "Windows" key as main modifier

      # Binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
      bind = [
        "$mainMod CONTROL SHIFT, M, exit"
        "$mainMod, M, exec, systemctl suspend-then-hibernate"
        "$mainMod SHIFT, M, exec, systemctl hibernate"
        "$mainMod CONTROL, M, exec, ${pkgs.hyprlock}/bin/hyprlock"
        "$mainMod, R, exec, $menu"

        # Hitokoto & Wallpaper (shared wallpaper-quote helper)
        ", XF86Tools, exec, ${lib.getExe wallpaperQuote} default"
        "SHIFT, XF86Tools, exec, ${lib.getExe wallpaperQuote} anime"
        "CONTROL, XF86Tools, exec, ${lib.getExe wallpaperQuote} none"
        "CONTROL SHIFT, XF86Tools, exec, ${lib.getExe wallpaperQuote} alternate"

        ", mouse:275, workspace, e+1"
        ", mouse:276, workspace, e-1"

        # Terminals
        "$mainMod, RETURN, exec, $terminal"
        "$mainMod, SPACE, exec, $floatTerminal"

        # Window Actions
        "$mainMod SHIFT, Q, killactive"
        "$mainMod CONTROL SHIFT, Q, forcekillactive"

        # SUPER T toggle floating & center window
        "$mainMod, T, togglefloating"
        "$mainMod, T, centerwindow"

        # SUPER SHIFT T resize 70% & center window
        "$mainMod SHIFT, T, resizeactive, exact 70% 70%"
        "$mainMod SHIFT, T, centerwindow"

        "$mainMod, F, fullscreen"
        "$mainMod, A, fullscreen, 1"
        "$mainMod, G, pin"

        # Shortcut mainly for libinput-gestures
        "$mainMod SHIFT, F, setfloating"
        "$mainMod SHIFT, F, resizeactive, exact 70% 70%"
        "$mainMod SHIFT, F, centerwindow"
        "$mainMod CONTROL, F, settiled"

        # --- Window Management ---

        # Move workspaces to monitors
        "$mainMod SHIFT, H, movecurrentworkspacetomonitor, l"
        "$mainMod SHIFT, J, movecurrentworkspacetomonitor, d"
        "$mainMod SHIFT, K, movecurrentworkspacetomonitor, u"
        "$mainMod SHIFT, L, movecurrentworkspacetomonitor, r"
        "$mainMod SHIFT, b, movecurrentworkspacetomonitor, +1"
        "$mainMod, b, focusmonitor, +1"

        "$mainMod SHIFT, left, movecurrentworkspacetomonitor, l"
        "$mainMod SHIFT, right, movecurrentworkspacetomonitor, d"
        "$mainMod SHIFT, up, movecurrentworkspacetomonitor, u"
        "$mainMod SHIFT, down, movecurrentworkspacetomonitor, r"

        # Move focus -> HJKL & Arrows & Tab
        "$mainMod, up, cyclenext, prev"
        "$mainMod, down, cyclenext"
        "$mainMod, H, movefocus, l"
        "$mainMod, L, movefocus, r"
        "$mainMod, K, movefocus, u"
        "$mainMod, J, movefocus, d"
        "$mainMod, TAB, cyclenext"

        # Special workspaces
        "$mainMod, C, workspace, 200"

        "$mainMod SHIFT, C, movetoworkspace, 200"
        "$mainMod SHIFT, V, movetoworkspace, 201"

        # Special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        "$mainMod, left, workspace, e-1"
        "$mainMod, right, workspace, e+1"

        # Move/resize windows
        "$mainMod CONTROL, H, moveactive, -100 0"
        "$mainMod CONTROL, L, moveactive, 100 0"
        "$mainMod CONTROL, K, moveactive, 0 -100"
        "$mainMod CONTROL, J, moveactive, 0 100"

        "$mainMod CONTROL, left, moveactive, -100 0"
        "$mainMod CONTROL, right, moveactive, 100 0"
        "$mainMod CONTROL, up, moveactive, 0 -100"
        "$mainMod CONTROL, down, moveactive, 0 100"

        "$mainMod ALT, H, resizeactive, -100 0"
        "$mainMod ALT, L, resizeactive, 100 0"
        "$mainMod ALT, K, resizeactive, 0 -100"
        "$mainMod ALT, J, resizeactive, 0 100"

        "$mainMod ALT, left, resizeactive, -100 0"
        "$mainMod ALT, right, resizeactive, 100 0"
        "$mainMod ALT, up, resizeactive, 0 -100"
        "$mainMod ALT, down, resizeactive, 0 100"

        # --- Other Binds ---

        # screenshot
        "$mainMod SHIFT, A, exec, ${lib.getExe screenshootScript}"
        "$mainMod SHIFT ALT, A, exec, grim"
        ", Print, exec, ${lib.getExe screenshootScript}"
      ]
      ++ lib.flatten (
        map (i: [
          "$mainMod, ${toString i}, workspace, ${toString i}"
          "$mainMod SHIFT, ${toString i}, movetoworkspace, ${toString i}"
        ]) (lib.range 1 9)
      );

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Laptop multimedia keys for volume and LCD brightness
      bindel = [
        ", XF86AudioRaiseVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

        ", XF86MonBrightnessUp, exec, ${brightnessctl} s 10%+"
        ", XF86MonBrightnessDown, exec, ${brightnessctl} s 10%-"
      ]; # Media keys
      bindl = [
        ", XF86AudioNext, exec, ${playerctl} next"
        ", XF86AudioPause, exec, ${playerctl} play-pause"
        ", XF86AudioPlay, exec, ${playerctl} play-pause"
        ", XF86AudioPrev, exec, ${playerctl} previous"
      ];
    };
  };
}
