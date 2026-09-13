{ lib, ... }:
{
  options.machine.btrfs.impermanence = {
    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The path to the physical disk device.";
    };

    luksName = lib.mkOption {
      type = lib.types.str;
      default = "crypted";
    };

    retentionDays = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "How many days to keep old root subvolumes.";
    };

    persistdir = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "The path to the persistent directory.";
    };

    allowDiscards = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable TRIM support on LUKS.";
    };

    resumeDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Resume device to configure for hibernation, if any.";
    };

    resumeOffset = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Swap file resume offset to append to kernel params, if any.";
    };

    luksKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional bootstrap key file for Disko-managed LUKS.";
    };
  };
}
