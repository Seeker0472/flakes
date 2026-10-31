{
  imports = [
    ../../modules/bundles/development.nix
    ../../users/seeker/headless.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "devVM";
  system.stateVersion = "24.05";

  machine = {
    programs.nixvim.development.enable = true;

    secrets = {
      deploy = true;
      nixConfig.enable = true;
      webdav.enable = true;
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

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
