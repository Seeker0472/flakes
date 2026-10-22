{
  system = "x86_64-linux";
  hostName = "willow";
  stateVersion = "26.11";

  machine = {
    type = "server";

    programs.netbird.enable = true;
  };

  disk = {
    # GCP persistent disk as seen by the current instance. Update this if the
    # VM (and therefore the disk name) is recreated.
    device = "/dev/disk/by-id/scsi-0Google_PersistentDisk_miandisk";
    bootMode = "uefi";
    rootLabel = "nixos-willow";
  };
}
