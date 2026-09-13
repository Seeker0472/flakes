import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    ./disk.nix
    ./desktop.nix
    ./fancontrol
    ./hardware-configuration.nix
    ./it87.nix
    ./openrgb
  ];
}
