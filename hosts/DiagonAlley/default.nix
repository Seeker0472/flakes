import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    ./disk.nix
    ./desktop.nix
    ./fancontrol
    ./hardware-configuration.nix
    ../miLaptop/xbox-firmware-overlay.nix
    ./it87.nix
    ./emulation.nix
    ./openrgb
  ];
}
