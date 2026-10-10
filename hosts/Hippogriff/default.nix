import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    (
      { pkgs, ... }:
      {
        # Xiaomi Pad 6 Pro (liuqin, SM8475): the port flake (flake.nix
        # `liuqin` input) provides the kernel, firmware, device packages and
        # every hardware.liuqin.* option this module consumes.
        hardware.liuqin = {
          enable = true;
          # Wi-Fi SSH is the debug path; the unauthenticated USB root shell
          # stays off on a daily machine (the RAM installer keeps its own).
          debugTransport = "ssh";
          boot.loader = "uboot";
          storage.layout = "linux-partition";

          desktop.gnome = {
            enable = true;
            sessionUser = "seeker";
          };

          camera = {
            enable = true;
            autofocus.enable = true;
          };
          fingerprint.enable = true;
          mipps.enable = true;

          sensors = {
            # Hash of the stock ROM's vendor/etc/sensors/config archive
            # (operator-supplied; see the port's docs/PORTING-NOTES.md).
            sscConfigHash = "sha256-9IzksIEZq8NveGBaD5cBSgzNLCh7KmvdjKnEaubCOdU=";
          };
        };

        # ssh-ng:// store deployments from the build host (nix copy) need
        # the machine user to be trusted by the local daemon.
        nix.settings.trusted-users = [
          "root"
          "seeker"
        ];

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        hardware.bluetooth.enable = true;
        services.blueman.enable = true;

        # Audio inspection tools (alsaucm/arecord/amixer/aplay) plus the two
        # GNOME Quick Settings extensions the port ships.
        environment.systemPackages = [
          pkgs.alsa-utils
          pkgs.liuqinGnomeFlashlight
          pkgs.liuqinGnomeAutoBrightness
        ];

        # The flash LED has no /dev node, so its brightness attribute is
        # handed to the camera stack's group directly.
        services.udev.extraRules = ''
          SUBSYSTEM=="leds", KERNEL=="white:flash", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/white:flash/brightness", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/leds/white:flash/brightness"
        '';

        programs.dconf.profiles.user.databases = [
          {
            settings."org/gnome/shell".enabled-extensions = [
              "liuqin-flashlight@liuqin"
              "liuqin-autobrightness@liuqin"
            ];
          }
        ];

        hardware.i2c.enable = true;
        zramSwap.enable = true;

        # Input method: the laptop profile carries this block for PC laptops;
        # the tablet's machine.type is "others", so it is stated here.
        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5.waylandFrontend = true;
          fcitx5.addons = with pkgs; [
            kdePackages.fcitx5-chinese-addons
            fcitx5-gtk
          ];
        };
      }
    )
  ];
}
