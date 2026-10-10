{
  system = "x86_64-linux";
  hostName = "kings-cross";
  stateVersion = "26.05";

  machine.type = "server";

  machine.programs.nixvim.enable = true;

  disk = {
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_6c51f2ff-72fe-438f-b423-2422e90231c0";
    bootMode = "bios";
  };
}
