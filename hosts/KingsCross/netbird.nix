{
  config,
  lib,
  pkgs,
  ...
}:
let
  shared = import ../lib/hardened-service.nix;
  domain = "netbird.vps.seekerer.com";
  publicPort = 28443;
  relayPort = 28444;
  stunPort = 28478;
  backendPort = 8081;
  publicUrl = "https://${domain}:${toString publicPort}";
  relayUrl = "rels://${domain}:${toString relayPort}";
  stateDirectory = "/var/lib/netbird";
  certificateDirectory = config.security.acme.certs.${domain}.directory;
  relayCredentialsDirectory = "/run/credentials/netbird-relay.service";

  netbirdServer = pkgs.netbird.override {
    componentName = "combined";
  };
in
{
  environment.systemPackages = [ netbirdServer ];

  users = {
    groups.netbird = { };
    users.netbird = {
      isSystemUser = true;
      group = "netbird";
      home = stateDirectory;
    };
  };

  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets =
      # alicloud_access_key / alicloud_secret_key are declared in secrets.nix.
      lib.genAttrs
        [
          "netbird_relay_auth_secret"
          "netbird_datastore_encryption_key"
          "netbird_idp_session_cookie_encryption_key"
        ]
        (name: {
          sopsFile = ./netbird.secrets.yaml;
          owner = "netbird";
          group = "netbird";
          restartUnits = lib.optional (name == "netbird_relay_auth_secret") "netbird-relay.service";
        });

    templates."netbird-config.yaml" = {
      owner = "netbird";
      group = "netbird";
      mode = "0400";
      restartUnits = [ "netbird-server.service" ];
      content = ''
        server:
          listenAddress: ":${toString backendPort}"
          exposedAddress: "${publicUrl}"
          # External relays disable the combined server's embedded relay/STUN.
          stuns:
            - uri: "stun:${domain}:${toString stunPort}"
          relays:
            addresses:
              - "${relayUrl}"
            credentialsTTL: "12h"
            secret: "${config.sops.placeholder.netbird_relay_auth_secret}"
          metricsPort: 9090
          healthcheckAddress: "127.0.0.1:9000"
          logLevel: "info"
          logFile: "console"
          disableAnonymousMetrics: true
          disableGeoliteUpdate: true
          authSecret: "${config.sops.placeholder.netbird_relay_auth_secret}"
          dataDir: "${stateDirectory}"
          auth:
            issuer: "${publicUrl}/oauth2"
            localAuthDisabled: false
            signKeyRefreshEnabled: true
            sessionCookieEncryptionKey: "${config.sops.placeholder.netbird_idp_session_cookie_encryption_key}"
            dashboardRedirectURIs:
              - "${publicUrl}/nb-auth"
              - "${publicUrl}/nb-silent-auth"
            dashboardPostLogoutRedirectURIs:
              - "${publicUrl}/"
            cliRedirectURIs:
              - "http://localhost:53000/"
          store:
            engine: "sqlite"
            encryptionKey: "${config.sops.placeholder.netbird_datastore_encryption_key}"
          reverseProxy:
            trustedHTTPProxies:
              - "127.0.0.1/32"
              - "::1/128"
            trustedPeers:
              - "127.0.0.1/32"
              - "::1/128"
      '';
    };
  };

  systemd.services.netbird-server = {
    description = "NetBird combined server";
    documentation = [ "https://docs.netbird.io/selfhosted/" ];
    environment.NB_DISABLE_GEOLOCATION = "true";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "netbird-relay.service"
    ];
    after = [
      "network-online.target"
      "sops-nix.service"
      "netbird-relay.service"
    ];
    serviceConfig = {
      Type = "simple";
      User = "netbird";
      Group = "netbird";
      StateDirectory = "netbird";
      StateDirectoryMode = "0750";
      WorkingDirectory = stateDirectory;
      ExecStart = "${lib.getExe netbirdServer} --config ${
        config.sops.templates."netbird-config.yaml".path
      }";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
    }
    // shared.serviceConfig;
  };

  # QUIC needs TLS in the relay itself, with credentials scoped to this unit.
  systemd.services.netbird-relay = {
    environment = {
      NB_TLS_CERT_FILE = "${relayCredentialsDirectory}/tls_cert";
      NB_TLS_KEY_FILE = "${relayCredentialsDirectory}/tls_key";
    };
    wants = [ "acme-finished-${domain}.target" ];
    after = [
      "sops-nix.service"
      "acme-finished-${domain}.target"
    ];
    serviceConfig.LoadCredential = lib.mkAfter [
      "tls_cert:${certificateDirectory}/fullchain.pem"
      "tls_key:${certificateDirectory}/key.pem"
    ];
  };

  services = {
    netbird.relay = {
      enable = true;
      authSecretFile = config.sops.secrets.netbird_relay_auth_secret.path;
      settings = {
        listen-address = ":${toString relayPort}";
        exposed-address = relayUrl;
        enable-stun = true;
        stun-ports = [ stunPort ];
        health-listen-address = "127.0.0.1:9001";
      };
    };

    netbird.server.dashboard = {
      enable = true;
      enableNginx = false;
      domain = domain;
      managementServer = publicUrl;
      settings = {
        AUTH_AUDIENCE = "netbird-dashboard";
        AUTH_AUTHORITY = "${publicUrl}/oauth2";
        AUTH_CLIENT_ID = "netbird-dashboard";
        AUTH_CLIENT_SECRET = "";
        AUTH_REDIRECT_URI = "/nb-auth";
        AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
        AUTH_SUPPORTED_SCOPES = "openid profile email groups";
        NETBIRD_TOKEN_SOURCE = "accessToken";
        USE_AUTH0 = false;
      };
    };

    nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts.${domain} = {
        onlySSL = true;
        useACMEHost = domain;
        listen = shared.mkSslListen publicPort;
        root = config.services.netbird.server.dashboard.finalDrv;

        extraConfig = ''
          client_header_timeout 1d;
          client_body_timeout 1d;
        '';

        locations = {
          "~ ^/ws-proxy/" = {
            proxyPass = "http://127.0.0.1:${toString backendPort}";
            proxyWebsockets = true;
            recommendedProxySettings = false;
            extraConfig = ''
              proxy_set_header Host ${domain}:${toString publicPort};
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Real-Port $remote_port;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto https;
              proxy_set_header X-Forwarded-Host ${domain}:${toString publicPort};
              proxy_read_timeout 1d;
              proxy_send_timeout 1d;
            '';
          };

          "~ ^/(signalexchange\\.SignalExchange|management\\.(ManagementService|ProxyService))/" = {
            extraConfig = ''
              grpc_pass grpc://127.0.0.1:${toString backendPort};
              grpc_set_header Host ${domain}:${toString publicPort};
              grpc_set_header X-Real-IP $remote_addr;
              grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              grpc_set_header X-Forwarded-Proto https;
              grpc_set_header X-Forwarded-Host ${domain}:${toString publicPort};
              grpc_read_timeout 1d;
              grpc_send_timeout 1d;
              grpc_socket_keepalive on;
            '';
          };

          "~ ^/(api|oauth2)(/|$)" = {
            proxyPass = "http://127.0.0.1:${toString backendPort}";
            recommendedProxySettings = false;
            extraConfig = ''
              proxy_set_header Host ${domain}:${toString publicPort};
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto https;
              proxy_set_header X-Forwarded-Host ${domain}:${toString publicPort};
              proxy_read_timeout 1d;
            '';
          };

          "= /nb-auth".tryFiles = "/index.html =404";
          "= /nb-silent-auth".tryFiles = "/index.html =404";

          "/" = {
            tryFiles = "$uri $uri.html $uri/ =404";
          };

          "= /404.html".extraConfig = "internal;";
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "gmx472@qq.com";
    certs.${domain} = (shared.mkAlidnsCert { inherit config; }) // {
      reloadServices = [ "netbird-relay.service" ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      publicPort
      relayPort
    ];
    allowedUDPPorts = [
      relayPort
      stunPort
    ];
  };
}
