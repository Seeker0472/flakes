{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.machine.hardware.tlp.usbDenylist = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "320f:5088"
      "046d:c52b"
    ];
    description = "USB device VID:PID pairs denied autosuspend by TLP.";
  };
  config = lib.mkIf (config.machine.type == "laptop") {
    services.logind.settings.Login = {
      # don't shutdown when power button is short-pressed
      HandlePowerKey = "ignore";
    };
    environment.systemPackages = [
      pkgs.powertop
      pkgs.pulseaudioFull
    ];
    boot.supportedFilesystems = [ "exfat" ];

    #mirror and allfirmware
    hardware.enableAllFirmware = true;
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        # no suspend for mouse and keyboard
        USB_DENYLIST = lib.concatStringsSep " " config.machine.hardware.tlp.usbDenylist;

        # USB_AUTOSUSPEND = 0;
      };
    };
    #nixpkgs.config.permittedInsecurePackages = ["openssl-1.1.1w"];
    powerManagement.powertop.enable = false;
    powerManagement.enable = true;
    # systemd.extraConfig
    systemd.settings.Manager = {
      DefaultTimeoutStopSec = "10s";
    };
    # Enable touchpad support (enabled default in most desktopManager).
    services.libinput.enable = true;

    services.upower.enable = true;
  };
}
