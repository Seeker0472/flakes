{
  config,
  lib,
  pkgs,
  ...
}:
let
  effectsProfile = "quickshell.json";
  # OpenRGB 1.0 uses plugin API 5.  nixpkgs still ships the 1.0rc2
  # effects plugin (API 4), which OpenRGB silently rejects at startup.
  effectsPlugin = pkgs.openrgb-plugin-effects.overrideAttrs (_: {
    version = "1.0";
    src = pkgs.fetchFromGitLab {
      owner = "OpenRGBDevelopers";
      repo = "OpenRGBEffectsPlugin";
      tag = "release_1.0";
      hash = "sha256-+LUP/KVKU7taHIOd274dbcaq/uljACTj/y3TUoaf3iM=";
      fetchSubmodules = true;
    };
  });
  effectsOpenRGB = pkgs.openrgb.withPlugins [ effectsPlugin ];
  controller = pkgs.writeShellApplication {
    name = "openrgb-control";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      export OPENRGB_CONTROL_TEMPLATE=${./spectrum-cycle.json}
      export OPENRGB_CONTROL_OPENRGB=${lib.getExe pkgs.openrgb}
      export OPENRGB_CONTROL_SYSTEMCTL=${pkgs.systemd}/bin/systemctl
      exec ${lib.getExe pkgs.python3} ${./controller.py} "$@"
    '';
  };
in
{
  # Gigabyte's ACPI tables reserve the AMD SMBus I/O range, preventing
  # i2c-piix4 from binding and OpenRGB from detecting RGB DIMMs.
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
    package = pkgs.openrgb;
    startupProfile = "default";
  };

  # Seed OpenRGB's writable state. OpenRGB 1.1 migrates the legacy .orp
  # profile from this directory into profiles/default.json before loading it.
  systemd.services.openrgb.preStart = ''
    ${pkgs.coreutils}/bin/install -m 0644 \
      ${./default.orp} \
      /var/lib/OpenRGB/default.orp
    ${pkgs.coreutils}/bin/install -m 0644 \
      ${./sizes.ors} \
      /var/lib/OpenRGB/sizes.ors
  '';

  home-manager.users.${config.machine.mainUser} = {
    programs.niri-shell.rgbControl = {
      enable = true;
      package = controller;
    };

    systemd.user.services.openrgb-effects = {
      Unit = {
        Description = "Synchronized OpenRGB effects";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Environment = "OPENRGB_EFFECTS_PLUGIN_STARTUP_PROFILE=${effectsProfile}";
        RuntimeDirectory = "openrgb-effects";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = [
          "${lib.getExe controller} wait-server"
          "${lib.getExe controller} prepare %t/openrgb-effects"
        ];
        ExecStart = lib.escapeShellArgs [
          (lib.getExe effectsOpenRGB)
          "--noautoconnect"
          "--client"
          "127.0.0.1:6742"
          "--server"
          "--server-host"
          "127.0.0.1"
          "--server-port"
          "6743"
          "--nodetect"
          "--startminimized"
          "--config"
          "%t/openrgb-effects"
        ];
        ExecStartPost = "${lib.getExe controller} restore";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
