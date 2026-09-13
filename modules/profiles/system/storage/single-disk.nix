{
  config,
  lib,
  ...
}:
let
  cfg = config.machine.disko;
  partitions =
    lib.optionalAttrs (cfg.bootMode == "bios") {
      bios = {
        size = "1M";
        type = "EF02";
      };
    }
    // lib.optionalAttrs (cfg.bootMode == "uefi") {
      ESP = import ./esp.nix;
    }
    // {
      root = {
        size = "100%";
        content = {
          type = "filesystem";
          format = "ext4";
          extraArgs = [
            "-L"
            cfg.rootLabel
          ];
          mountpoint = "/";
          mountOptions = cfg.mountOptions;
        };
      };
    };
in
{
  options.machine.disko = {
    enable = lib.mkEnableOption "a minimal single-disk Disko layout";
    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/disk/by-id/scsi-example";
      description = "Stable path of the disk that nixos-anywhere may erase and provision.";
    };
    bootMode = lib.mkOption {
      type = lib.types.enum [
        "bios"
        "uefi"
      ];
      default = "uefi";
      description = "Firmware mode used to partition the disk and install GRUB.";
    };
    rootLabel = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Filesystem label for the ext4 root partition.";
    };
    efiCanTouchVariables = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the UEFI boot loader may create a firmware boot entry.";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "defaults"
        "noatime"
      ];
      description = "Mount options for the root filesystem.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.device != null;
            message = "machine.disko.device must be set when the single-disk layout is enabled.";
          }
        ];

        boot.loader.grub = {
          enable = true;
          devices = lib.mkIf (cfg.bootMode == "uefi") [ "nodev" ];
          efiSupport = cfg.bootMode == "uefi";
          efiInstallAsRemovable = cfg.bootMode == "uefi" && !cfg.efiCanTouchVariables;
        };
        boot.loader.efi = lib.mkIf (cfg.bootMode == "uefi") {
          canTouchEfiVariables = cfg.efiCanTouchVariables;
        };
      }

      (lib.mkIf (cfg.device != null) {
        disko.devices.disk.main = {
          type = "disk";
          device = cfg.device;
          content = {
            type = "gpt";
            inherit partitions;
          };
        };
      })
    ]
  );
}
