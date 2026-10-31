{
  imports = [
    ../../modules/bundles/server.nix
    ../../modules/profiles/system/core/vps.nix
    ../../modules/profiles/programs/netbird.nix
    ./mihomo.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "willow";
  system.stateVersion = "26.11";

  machine = {
    type = "server";

    programs.netbird.enable = true;
  };

  machine.disko = {
    enable = true;
    # GCP persistent disk as seen by the current instance. Update this if the
    # VM (and therefore the disk name) is recreated.
    device = "/dev/disk/by-id/scsi-0Google_PersistentDisk_miandisk";
    bootMode = "uefi";
    rootLabel = "nixos-willow";
  };
}
