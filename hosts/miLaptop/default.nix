import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    ./disk.nix
    ./hardware-configuration.nix
    ./xbox-firmware-overlay.nix
    (
      { pkgs, ... }:
      {
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_PATH}=="platform-i8042-serio-0", RUN+="${pkgs.kbd}/bin/setkeycodes e072 183"
        '';
      }
    )
    (
      { pkgs, ... }:
      {
        services.smartd = {
          enable = true;
          autodetect = true;
          notifications.systembus-notify.enable = true;
        };

        environment.systemPackages = [ pkgs.smartmontools ];
      }
    )
    (
      { ... }:
      {
        # deploy-rs pushes the closure over the ssh-ng store; the machine user
        # must be allowed to import unsigned paths (nixpkgs trusts root only).
        nix.settings.trusted-users = [
          "root"
          "seeker"
        ];
      }
    )
  ];
}
