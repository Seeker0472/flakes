{
  system = "x86_64-linux";
  hostName = "kings-cross";
  stateVersion = "26.05";

  machine.type = "server";

  machine.programs.nixvim.enable = true;

  disk = {
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_0068e137-6410-451b-8733-d8fc25f088c7";
    bootMode = "bios";
  };
}
