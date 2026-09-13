{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Verified from the NixOS Live ISO: Gigabyte B650M AORUS ELITE AX ICE,
  # Ryzen 9 9950X, RTX 5070, Intel AX210 Wi-Fi, Realtek 2.5GbE, two internal
  # Samsung NVMe disks, and one Samsung NVMe in a USB enclosure.
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "uas"
    "usbhid"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableAllFirmware = true;

  # Root, /nix, /persist, swap and /boot are declared by disk.nix through the
  # shared Btrfs impermanence/Disko module.

  hardware.graphics.enable = true;
  hardware.nvidia = {
    # RTX 5070 (Blackwell) uses the open NVIDIA kernel module.
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  services.smartd = {
    enable = true;
    autodetect = true;
  };

  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
