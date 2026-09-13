{ config, ... }:
{
  imports = [
    (import ../lib/impermanence-disk.nix {
      inherit config;
      extraDirectories = [
        # QQ/WeChat and other Flatpak-style state lives under the persisted
        # home; nothing host-specific here beyond the systemd coredump dir.
        "/var/lib/systemd/coredump"
      ];
    })
  ];

  config = {
    machine.btrfs.impermanence = {
      luksName = "crypted";
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLB256HAHQ-000L7_S41GNA0K906073";
      retentionDays = 30;
      allowDiscards = true;

      # systemd records the selected swapfile and its current Btrfs offset in
      # the HibernateLocation EFI variable. Avoid a stale static offset when
      # the Disko-managed swapfile is recreated.
      resumeDevice = null;
      resumeOffset = null;
      luksKeyFile = null;
    };

    systemd.sleep.settings.Sleep = {
      AllowHibernation = "yes";
      AllowSuspendThenHibernate = "yes";
    };
  };
}
