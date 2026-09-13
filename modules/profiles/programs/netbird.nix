{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.machine.programs.netbird;
  client = config.services.netbird.clients.default;
in
{
  options.machine.programs.netbird = {
    enable = lib.mkEnableOption "NetBird";

    managementUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://netbird.vps.seekerer.com:28443";
      description = "URL of the NetBird management service.";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      services = {
        netbird = {
          useRoutingFeatures = "client";
          ui.enable = false;

          clients.default = {
            port = 51820;
            name = "netbird";
            interface = "wt0";
            hardened = true;
            environment = {
              NB_MANAGEMENT_URL = cfg.managementUrl;
              NB_ADMIN_URL = cfg.managementUrl;
            };
          };
        };

        # mkDefault so other modules (e.g. mihomo tun mode) can win the
        # priority over resolved without a priority conflict.
        resolved.enable = lib.mkDefault true;
      };

      users.users.${config.machine.mainUser}.extraGroups = [ client.user.group ];
    }
    // lib.optionalAttrs (options ? environment.persistence) {
      environment.persistence = lib.mkIf config.machine.impermanence.enable {
        "${config.machine.btrfs.impermanence.persistdir}".directories = [ client.dir.state ];
      };
    }
  );
}
