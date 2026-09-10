{ config, ... }:
let
  mainUser = config.machine.mainUser;
  mainUserGroup = config.users.users.${mainUser}.group;
  persistHome = "${config.machine.btrfs.impermanence.persistdir}/home/${mainUser}";
in
{
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

    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };

    boot.initrd.availableKernelModules = [
      "tpm_crb"
    ];

    boot.supportedFilesystems = [
      "ntfs"
      "exfat"
    ];

    fileSystems."${config.machine.btrfs.impermanence.persistdir}".neededForBoot = true;
    environment.persistence."${config.machine.btrfs.impermanence.persistdir}" = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/lib/NetworkManager"
        "/var/lib/cups"
        "/var/lib/libvirt"
        "/etc/NetworkManager/system-connections"
        "/var/lib/docker"
        "/var/lib/private/mihomo"
        "/var/lib/OpenRGB"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
      users.${config.machine.mainUser} = {
        directories = [
          "nixos-config"
          {
            directory = ".config";
            mode = "0755";
          }
          {
            directory = ".config/sops";
            mode = "0700";
          }
          {
            directory = ".config/sops/age";
            mode = "0700";
          }
          ".local/share/z"
          "Develop"
          ".mozilla"
        ];
      };
    };

    # Persistence trees may predate this host configuration. Repair the SOPS
    # ownership and modes before Home Manager or sops-nix starts.
    systemd.tmpfiles.rules = [
      "d ${persistHome}/.config 0755 ${mainUser} ${mainUserGroup} -"
      "z ${persistHome}/.config 0755 ${mainUser} ${mainUserGroup} -"
      "d ${persistHome}/.config/sops 0700 ${mainUser} ${mainUserGroup} -"
      "z ${persistHome}/.config/sops 0700 ${mainUser} ${mainUserGroup} -"
      "d ${persistHome}/.config/sops/age 0700 ${mainUser} ${mainUserGroup} -"
      "z ${persistHome}/.config/sops/age 0700 ${mainUser} ${mainUserGroup} -"
      "z ${persistHome}/.config/sops/age/keys.txt 0600 ${mainUser} ${mainUserGroup} -"
    ];
  };
}
