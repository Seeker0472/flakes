{
  imports = [
    {
      boot.kernelParams = [ "console=ttyS0,115200n8" ];

      boot.loader.grub = {
        enable = true;
        device = "nodev";
      };

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      virtualisation.vmVariantWithBootLoader.virtualisation = {
        cores = 384;
        # qcow2 allocates host storage on demand; this is only its virtual ceiling.
        diskSize = 1024 * 1024;
        graphics = false;
        memorySize = 1024 * 1024;
        qemu.options = [ "-machine q35" ];
      };
    }
  ];
}
