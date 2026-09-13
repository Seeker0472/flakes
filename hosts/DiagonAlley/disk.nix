{ config, ... }:
{
  imports = [
    (import ../lib/impermanence-disk.nix {
      inherit config;
      extraDirectories = [
        "/var/lib/systemd"
        "/var/lib/libvirt"
        "/var/lib/OpenRGB"
      ];
    })
  ];

  config = {
    machine.btrfs.impermanence = {
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NU0W123827";
      luksName = "crypted";
      retentionDays = 30;
      allowDiscards = true;

      # Calculate these only after the final swapfile has been created. Null
      # keeps hibernation disabled until the real values are known.
      resumeDevice = null;
      resumeOffset = null;

      # Leave this null to let Disko prompt for the LUKS password. Do not put
      # a private key or password in the repository.
      luksKeyFile = null;
    };
  };
}
