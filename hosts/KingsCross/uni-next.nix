{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  netbirdApiUrl = "https://netbird.vps.seekerer.com:28443";
  netbirdRange = "100.4.0.0/16";
  netbirdClient = config.services.netbird.clients.uni-next;
  tokenPath = config.sops.secrets.netbird-uni-next-api-token.path;
  desired = {
    api_url = netbirdApiUrl;
    source_cidr = netbirdRange;
    network_name = "uni-next-kingscross";
    resource_name = "uni-next-dev-machine";
    resource_address = "10.19.20.1/32";
    router_group = "uni-next-kingscross-router";
    resource_group = "uni-next-kingscross-resources";
    source_groups = [ "All" ];
    policy_name = "uni-next-kingscross-access";
    setup_key_name = "uni-next-kingscross-once";
    description = "Managed by nixos-config: KingsCross UniVPN gateway";
  };
  desiredFile = (pkgs.formats.json { }).generate "netbird-uni-next-desired.json" desired;
in
{
  imports = [ inputs.uni-next.nixosModules.default ];

  sops.secrets = {
    uni-next-vpn-password = {
      sopsFile = ./uni-next.secrets.yaml;
      key = "vpn_password";
      restartUnits = [ "uni-next.service" ];
    };
    uni-next-logout-user-id = {
      sopsFile = ./uni-next.secrets.yaml;
      key = "logout_user_id";
      restartUnits = [ "uni-next.service" ];
    };
    netbird-uni-next-api-token = {
      sopsFile = ./uni-next-api.secrets.yaml;
      key = "netbird_api_token";
      mode = "0400";
      restartUnits = [ "netbird-uni-next-sync.service" ];
    };
  };

  services.netbird = {
    useRoutingFeatures = "both";
    clients.uni-next = {
      port = 28479;
      interface = "nb-uni-next";
      ui.enable = false;
    };
  };

  services.uni-next = {
    enable = true;
    netbirdService = "netbird-uni-next.service";
    credentials = {
      vpnPasswordFile = config.sops.secrets.uni-next-vpn-password.path;
      logoutUserIDFile = config.sops.secrets.uni-next-logout-user-id.path;
    };
    settings = {
      schema_version = 1;
      protocol.profile = "cnem-base-v1";
      server = {
        host = "220.181.17.10";
        port = 9443;
      };
      auth = {
        username = "seeker472@oseda";
        mac = "06:e1:96:a2:45:59";
      };
      tls.spki_sha256 = [ "tv3+jhIra3BsEAf8Ptp95b5B3Oc79DSIJH75X9ceb0o=" ];
      network = {
        tun_name = "uni-next0";
        mtu = 1300;
        allowed_routes = [ "10.19.20.0/24" ];
        table = 20000;
        rule_priority = 100;
      };
      reconnect = {
        network.enabled = true;
        initial = "5s";
        maximum = "1m";
        reset_after = "5m";
        kickout = {
          mode = "bounded";
          window = "10m";
          max_retries = 3;
        };
      };
      socks.enabled = false;
      http.enabled = false;
      gateway = {
        mode = "netbird";
        ingress_interface = netbirdClient.interface;
        source_cidrs = [ netbirdRange ];
        export_routes = [ desired.resource_address ];
        clamp_tcp_mss = true;
      };
    };
  };

  systemd.services.netbird-uni-next-sync = {
    description = "Reconcile KingsCross UniVPN resource with NetBird API";
    wantedBy = [ "multi-user.target" ];
    requires = [ "netbird-uni-next.service" ];
    after = [
      "netbird-uni-next.service"
      "netbird-server.service"
      "sops-nix.service"
    ];
    unitConfig.ConditionPathExists = tokenPath;
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "netbird-uni-next-sync";
      RuntimeDirectoryMode = "0700";
      LoadCredential = [ "api-token:${tokenPath}" ];
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.python3}/bin/python3"
        "${./netbird-uni-next-sync.py}"
        "--config ${desiredFile}"
        "--token-file %d/api-token"
        "--netbird-bin ${lib.getExe netbirdClient.wrapper}"
        "--runtime-dir /run/netbird-uni-next-sync"
      ];
      TimeoutStartSec = "180s";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      UMask = "0077";
    };
  };

  systemd.timers.netbird-uni-next-sync = {
    description = "Periodically reconcile the KingsCross UniVPN NetBird resource";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };
}
