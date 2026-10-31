{ inputs, ... }:
{
  imports = [
    ../../modules/bundles/server.nix
    ./netbird.nix
    ./secrets.nix
    ./taskchampion.nix
    ./personal-storage
    ./uni-next.nix
    ../../modules/profiles/system/core/vps.nix
    inputs.nixvim.nixosModules.nixvim
    ../../modules/profiles/programs/nixvim/default.nix
  ];

  programs.nixvim = {
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
  services.qemuGuest.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "kings-cross";
  system.stateVersion = "26.05";

  machine.type = "server";

  machine.programs.nixvim.enable = true;

  machine.disko = {
    enable = true;
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_6c51f2ff-72fe-438f-b423-2422e90231c0";
    bootMode = "bios";
  };
}
