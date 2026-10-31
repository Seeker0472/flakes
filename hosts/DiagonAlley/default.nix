{
  imports = [
    ./disk.nix
    ./fancontrol
    ./hardware-configuration.nix
    ../miLaptop/xbox-firmware-overlay.nix
    ./it87.nix
    ./emulation.nix
    ./openrgb
  ];
}
