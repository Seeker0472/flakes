{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.machine.programs.winapps;
  system = pkgs.stdenv.hostPlatform.system;
  winapps = inputs.winapps;
in
{
  options.machine.programs.winapps.enable = lib.mkEnableOption "WinApps";

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        winapps.packages."${system}".winapps
        winapps.packages."${system}".winapps-launcher
      ];
    })
    (lib.mkIf (cfg.enable && config.machine.impermanence.enable) {
      environment.persistence."${config.machine.btrfs.impermanence.persistdir}" = {
        users.${config.machine.mainUser}.directories = [
          ".config/winapps"
        ];
      };
    })
  ];
}
