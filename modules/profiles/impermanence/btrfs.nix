{
  config,
  lib,
  ...
}:

let
  cfg = config.machine.btrfs.impermanence;
in
{
  config = lib.mkIf config.machine.impermanence.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.device != null;
            message = "machine.btrfs.impermanence.device must be set when impermanence is enabled.";
          }
          {
            assertion = (cfg.resumeDevice == null) == (cfg.resumeOffset == null);
            message = "machine.btrfs.impermanence.resumeDevice and resumeOffset must be configured together.";
          }
        ];

        boot.initrd.systemd.enable = true;
        boot.initrd.supportedFilesystems = [ "btrfs" ];
        boot.initrd.availableKernelModules = [
          "btrfs"
          "crc32c"
        ];
        boot.initrd.luks.devices."${cfg.luksName}".crypttabExtraOpts = [ "tpm2-device=auto" ];
        boot.initrd.systemd.services.create-needed-for-boot-dirs.after = [ "local-fs-pre.target" ];

        # 2. 回滚逻辑 (提取出来的通用脚本)
        boot.initrd.systemd.services.rollback = {
          description = "Rollback BTRFS root subvolume to a pristine state";
          wantedBy = [ "initrd.target" ];
          after = [
            "systemd-cryptsetup@${cfg.luksName}.service"
            "systemd-hibernate-resume.service"
          ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            mkdir -p /btrfs_tmp
            mount /dev/mapper/${cfg.luksName} /btrfs_tmp

            if [[ -e /btrfs_tmp/root ]]; then
                mkdir -p /btrfs_tmp/old_roots
                timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
                mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
            fi

            delete_subvolume_recursively() {
                IFS=$'\n'
                for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                    delete_subvolume_recursively "/btrfs_tmp/$i"
                done
                btrfs subvolume delete "$1"
            }

            # 使用变量控制保留天数
            for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +${toString cfg.retentionDays}); do
                delete_subvolume_recursively "$i"
            done

            btrfs subvolume create /btrfs_tmp/root
            umount /btrfs_tmp
          '';
        };

        # 3. Disko 配置 (使用变量生成)
        disko.devices.disk.main = lib.mkIf (cfg.device != null) {
          type = "disk";
          device = cfg.device;
          content = {
            type = "gpt";
            partitions = {
              ESP = import ../system/storage/esp.nix;
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = cfg.luksName;
                  settings.allowDiscards = cfg.allowDiscards;
                }
                // lib.optionalAttrs (cfg.luksKeyFile != null) {
                  keyFile = cfg.luksKeyFile;
                }
                // {
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes = {
                      "/root" = {
                        mountpoint = "/";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "/nix" = {
                        mountpoint = "/nix";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "${cfg.persistdir}" = {
                        mountpoint = "${cfg.persistdir}";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "/swap" = {
                        mountpoint = "/.swapvol";
                        swap.swapfile.size = "32G";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      }
      (lib.mkIf (cfg.resumeDevice != null) {
        boot.resumeDevice = cfg.resumeDevice;
      })
      (lib.mkIf (cfg.resumeOffset != null) {
        boot.kernelParams = [ "resume_offset=${toString cfg.resumeOffset}" ];
      })
    ]
  );
}
