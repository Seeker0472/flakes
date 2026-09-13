# Shared impermanence/Disko plumbing for hosts on the shared Btrfs
# impermanence profile. Each host supplies its own device/LUKS data and any
# extra persistence entries; this module provides the common persistence
# directory/file lists and the sops/age tmpfiles repair rules.
#
# The user's .config/sops/age tree is repaired by tmpfiles only (not via
# environment.persistence mode rules): tmpfiles `z` repairs ownership and
# modes on pre-existing persistence trees that predate this configuration,
# which environment.persistence cannot do.
{
  config,
  extraDirectories ? [ ],
  extraUserDirectories ? [ ],
}:
let
  mainUser = config.machine.mainUser;
  mainUserGroup = config.users.users.${mainUser}.group;
  persistHome = "${config.machine.btrfs.impermanence.persistdir}/home/${mainUser}";
in
{
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
      "/var/lib/NetworkManager"
      "/var/lib/cups"
      "/etc/NetworkManager/system-connections"
      "/var/lib/docker"
      "/var/lib/private/mihomo"
    ]
    ++ extraDirectories;
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    users.${mainUser} = {
      directories = [
        "nixos-config"
        {
          directory = ".config";
          mode = "0755";
        }
        ".local/share/z"
        "Develop"
        ".mozilla"
      ]
      ++ extraUserDirectories;
    };
  };

  # Existing persistence trees keep their old ownership; repair only the
  # user-owned SOPS/config boundary before Home Manager starts.
  systemd.tmpfiles.rules = [
    "d ${persistHome}/.config 0755 ${mainUser} ${mainUserGroup} -"
    "z ${persistHome}/.config 0755 ${mainUser} ${mainUserGroup} -"
    "d ${persistHome}/.config/sops 0700 ${mainUser} ${mainUserGroup} -"
    "z ${persistHome}/.config/sops 0700 ${mainUser} ${mainUserGroup} -"
    "d ${persistHome}/.config/sops/age 0700 ${mainUser} ${mainUserGroup} -"
    "z ${persistHome}/.config/sops/age 0700 ${mainUser} ${mainUserGroup} -"
    "z ${persistHome}/.config/sops/age/keys.txt 0600 ${mainUser} ${mainUserGroup} -"
  ];
}
