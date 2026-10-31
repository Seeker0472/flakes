{ lib, config, ... }:
{
  config = lib.mkIf (config.programs.steam.enable && config.machine.impermanence.enable) {
    environment.persistence."${config.machine.btrfs.impermanence.persistdir}" = {
      users.${config.machine.mainUser}.directories = [
        ".steam"
        ".local/share/Steam"
      ];
    };
  };
}
