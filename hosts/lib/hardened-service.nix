# Shared hardening and TLS helpers for KingsCross (VPS) services.
# These only shape module options; per-service values are supplied by callers.
{
  # Baseline systemd sandbox shared by the public-facing services on the VPS.
  # Callers may extend it with service-specific keys (Type, User, ExecStart, ...).
  serviceConfig = {
    AmbientCapabilities = [ ];
    CapabilityBoundingSet = [ ];
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
  };

  # ACME certificate via AliDNS. The VPS cannot reliably query every AliDNS
  # authoritative server over IPv6, so wait for propagation instead of making
  # issuance depend on that network path.
  mkAlidnsCert =
    { config }:
    {
      dnsProvider = "alidns";
      extraLegoFlags = [
        "--dns.propagation-wait"
        "30s"
      ];
      credentialFiles = {
        ALICLOUD_ACCESS_KEY_FILE = config.sops.secrets.alicloud_access_key.path;
        ALICLOUD_SECRET_KEY_FILE = config.sops.secrets.alicloud_secret_key.path;
      };
      group = config.services.nginx.group;
    };

  # Dual-stack SSL listen entries shared by the nginx virtual hosts on the VPS.
  mkSslListen = port: [
    {
      addr = "0.0.0.0";
      port = port;
      ssl = true;
    }
    {
      addr = "[::]";
      port = port;
      ssl = true;
    }
  ];
}
