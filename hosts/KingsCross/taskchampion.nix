{ config, ... }:
let
  shared = import ../lib/hardened-service.nix;
  domain = "vps.seekerer.com";
  publicPort = 28443;
  backendPort = 10222;
in
{
  sops = {
    secrets.taskchampion_client_id = {
      sopsFile = ../../users/seeker/taskwarrior.secrets.yaml;
      key = "client_id";
    };

    templates."taskchampion.env" = {
      mode = "0400";
      restartUnits = [ "taskchampion-sync-server.service" ];
      content = ''
        CLIENT_ID=${config.sops.placeholder.taskchampion_client_id}
      '';
    };
  };

  services = {
    taskchampion-sync-server = {
      enable = true;
      host = "127.0.0.1";
      port = backendPort;
    };

    nginx.virtualHosts.${domain} = {
      onlySSL = true;
      useACMEHost = domain;
      listen = shared.mkSslListen publicPort;

      locations."/".proxyPass = "http://127.0.0.1:${toString backendPort}";
    };
  };

  systemd.services.taskchampion-sync-server = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."taskchampion.env".path;
      Restart = "on-failure";
      RestartSec = "5s";
    }
    // shared.serviceConfig;
  };

  # The alicloud secrets used by this certificate are declared in secrets.nix.
  security.acme.certs.${domain} = shared.mkAlidnsCert { inherit config; };

  networking.firewall.allowedTCPPorts = [ publicPort ];
}
