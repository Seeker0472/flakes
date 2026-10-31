{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  deCfg = lib.attrByPath [ "machine" "de" ] { } osConfig;
  enabled = deCfg.quickshell.enable or false;
  taskEnabled = config.programs.taskwarrior.enable;
  taskCommand =
    if taskEnabled then
      lib.getExe config.programs.taskwarrior.package
    else
      "${pkgs.coreutils}/bin/false";
  fanCfg = config.programs.niri-shell.fanControl;
  fanCommand =
    if fanCfg.enable && fanCfg.package != null then
      lib.getExe fanCfg.package
    else
      "${pkgs.coreutils}/bin/false";
  rgbCfg = config.programs.niri-shell.rgbControl;
  rgbCommand =
    if rgbCfg.enable && rgbCfg.package != null then
      lib.getExe rgbCfg.package
    else
      "${pkgs.coreutils}/bin/false";
  swaylockCommand =
    if (deCfg.niri.enable or false) then lib.getExe pkgs.swaylock-effects else lib.getExe pkgs.swaylock;

  focusWorkspaceScript = pkgs.writeShellScriptBin "niri-shell-focus-workspace" ''
    output="''${1:-}"
    index="''${2:-1}"
    if [ -n "$output" ]; then
      ${pkgs.niri}/bin/niri msg action focus-monitor "$output"
    fi
    exec ${pkgs.niri}/bin/niri msg action focus-workspace "$index"
  '';

  btopScript = pkgs.writeShellScriptBin "niri-shell-btop" ''
    exec ${pkgs.kitty}/bin/kitty --class RTG ${pkgs.btop}/bin/btop
  '';

  taskTerminalScript = pkgs.writeShellScriptBin "niri-shell-taskwarrior" ''
    exec ${pkgs.kitty}/bin/kitty --class RTG ${pkgs.fish}/bin/fish -C '${taskCommand} next'
  '';

  cavaConfig = pkgs.writeText "niri-shell-cava.conf" ''
    [general]
    bars = 12
    framerate = 20
    autosens = 1

    [input]
    method = pipewire
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 8
    bar_delimiter = 59
  '';

  commands = pkgs.runCommand "niri-quickshell-config" { } ''
    mkdir -p "$out"
    cp -r ${./shell}/. "$out/"
    cp ${./sampler.py} "$out/sampler.py"
    chmod 0555 "$out/sampler.py"
    substitute ${./shell}/Commands.qml "$out/Commands.qml" \
      --subst-var-by niri ${lib.getExe pkgs.niri} \
      --subst-var-by focusWorkspace ${lib.getExe focusWorkspaceScript} \
      --subst-var-by btop ${lib.getExe btopScript} \
      --subst-var-by taskEnabled ${lib.boolToString taskEnabled} \
      --subst-var-by task ${taskCommand} \
      --subst-var-by taskTerminal ${
        if taskEnabled then lib.getExe taskTerminalScript else taskCommand
      } \
      --subst-var-by python ${lib.getExe pkgs.python3} \
      --subst-var-by sampler "$out/sampler.py" \
      --subst-var-by pwDump ${pkgs.pipewire}/bin/pw-dump \
      --subst-var-by ip ${pkgs.iproute2}/bin/ip \
      --subst-var-by nmcli ${pkgs.networkmanager}/bin/nmcli \
      --subst-var-by bluetoothctl ${pkgs.bluez}/bin/bluetoothctl \
      --subst-var-by brightnessctl ${lib.getExe pkgs.brightnessctl} \
      --subst-var-by wpctl ${pkgs.wireplumber}/bin/wpctl \
      --subst-var-by systemctl ${pkgs.systemd}/bin/systemctl \
      --subst-var-by loginctl ${pkgs.systemd}/bin/loginctl \
      --subst-var-by swaylock ${swaylockCommand} \
      --subst-var-by pavucontrol ${lib.getExe pkgs.pavucontrol} \
      --subst-var-by nmEditor ${pkgs.networkmanagerapplet}/bin/nm-connection-editor \
      --subst-var-by blueman ${pkgs.blueman}/bin/blueman-manager \
      --subst-var-by wpaperctl ${pkgs.wpaperd}/bin/wpaperctl \
      --subst-var-by playerctl ${lib.getExe pkgs.playerctl} \
      --subst-var-by cava ${lib.getExe pkgs.cava} \
      --subst-var-by cavaConfig ${cavaConfig} \
      --subst-var-by fanEnabled ${lib.boolToString fanCfg.enable} \
      --subst-var-by fanControl ${fanCommand} \
      --subst-var-by rgbEnabled ${lib.boolToString rgbCfg.enable} \
      --subst-var-by rgbControl ${rgbCommand}
  '';
in
{
  options.programs.niri-shell.fanControl = {
    enable = lib.mkEnableOption "fan controls in the Niri shell";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Package providing the fan-control executable.";
    };
  };

  options.programs.niri-shell.rgbControl = {
    enable = lib.mkEnableOption "the OpenRGB controls in the Niri shell";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Package providing the openrgb-control executable.";
    };
  };

  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = !fanCfg.enable || fanCfg.package != null;
        message = "programs.niri-shell.fanControl.package must be set when fan controls are enabled";
      }
      {
        assertion = !rgbCfg.enable || rgbCfg.package != null;
        message = "programs.niri-shell.rgbControl.package must be set when RGB controls are enabled";
      }
    ];

    xdg.configFile."quickshell/niri-shell".source = commands;

    home.packages =
      (with pkgs; [
        quickshell
        networkmanagerapplet
        blueman
        pavucontrol
      ])
      ++ lib.optional (fanCfg.enable && fanCfg.package != null) fanCfg.package
      ++ lib.optional (rgbCfg.enable && rgbCfg.package != null) rgbCfg.package;
  };
}
