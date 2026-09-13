{ lib, config, ... }:
{
  options.machine.programs.tailscale.enable = lib.mkEnableOption "Tailscale";
  config = lib.mkMerge [
    (lib.mkIf config.machine.programs.tailscale.enable {
      services.tailscale.enable = true;
      # Fix DNS conflict between tailscale and mihomo tun mode
      # (https://github.com/tailscale/tailscale/issues/4254). Resolved stays
      # on unless mihomo tun is active; mihomo itself turns resolved off then.
      services.resolved.enable = lib.mkDefault (
        !(config.machine.programs.mihomo.enable && config.machine.programs.mihomo.tun.enable)
      );
    })
    (lib.mkIf (config.machine.programs.tailscale.enable && config.machine.impermanence.enable) {
      environment.persistence."${config.machine.btrfs.impermanence.persistdir}" = {
        directories = [
          "/var/lib/tailscale"
        ];
      };
    })
  ];
}
