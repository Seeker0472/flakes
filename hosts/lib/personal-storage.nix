{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.personalStorage;
  shared = import ./hardened-service.nix;
  base = "/srv/personal-services";
  projectID = 3500;
  inodeLimit = 250000;
  ports = {
    https = 28443;
    sftp = 2222;
    copyparty = 3923;
    couchdb = 5984;
  };
  runtime = "/run/personal-storage";
  copyparty = pkgs.copyparty.override {
    withCertgen = false;
    withThumbnails = false;
    withMediaProcessing = false;
    withZeroMQ = false;
    withFTP = false;
  };
  python = "${pkgs.python3}/bin/python3";
  controller = "${python} ${./personal-storage.py} --config ${controllerConfig}";
  runtimeController = "${python} ${./personal-storage.py} --config ${runtime}/config.json";
  copypartyTemplate = pkgs.writeText "personal-storage-copyparty.conf" ''
    [global]
      i: 127.0.0.1
      p: ${toString ports.copyparty}
      http-only
      usernames
      rproxy: -1
      xff-src: 127.0.0.1/32
      ipr: ${cfg.netbirdCIDR}=manager
      hist: ${base}/copyparty/history
      ses-db: ${base}/copyparty/sessions.db
      chpw-db: ${base}/copyparty/passwords.json
      unpost: 0
      unp-who: 0
      u2abort: 0
      ftp-wt: 0
      blank-wt: 0
      apnd-who: dw
      no-dav
      no-thumb
      no-mtag-ff
      no-html
      no-readme
      no-logues
      no-robots
      no-voldump
      no-ansi
      log-badpwd: 0
      re-maxage: 60

    [/]
      ${base}/transfer
      accs:
        rw: transfer
        rwmda: manager
      flags:
        e2ds
        chmod_f: 640
        chmod_d: 750
  '';
  expiryConfig = pkgs.writeText "personal-storage-expire.conf" ''
    e ${base}/transfer - - - bB:${toString cfg.retentionSeconds}s -
  '';
  sftpConfig = pkgs.writeText "personal-storage-sshd.conf" ''
    Port ${toString ports.sftp}
    ListenAddress ${cfg.netbirdAddress}
    HostKey ${base}/sftp/host-key
    PidFile /run/personal-storage/sftp.pid
    UsePAM yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    AllowUsers copyparty@${cfg.netbirdCIDR}
    AuthorizedKeysFile ${cfg.sftpAuthorizedKeysFile}
    ChrootDirectory ${base}/sftp/root
    ForceCommand internal-sftp -d /files -u 0027
    DisableForwarding yes
    PermitTTY no
    Subsystem sftp internal-sftp
  '';
  controllerConfig = pkgs.writeText "personal-storage.json" (
    builtins.toJSON {
      base = base;
      runtime = runtime;
      mount = cfg.quotaMountPoint;
      project_id = projectID;
      quota_bytes = cfg.quotaBytes;
      inode_limit = inodeLimit;
      minimum_reserve_bytes = cfg.minimumReserveBytes;
      compaction_margin_bytes = cfg.compactionMarginBytes;
      cleanup_allowance_bytes = cfg.cleanupAllowanceBytes;
    }
  );
  quotaUnits = [
    "personal-storage-quota.service"
    "personal-storage-budget.service"
  ];
  guardedService = {
    requires = quotaUnits;
    after = quotaUnits ++ [ "sops-nix.service" ];
    bindsTo = quotaUnits;
    partOf = quotaUnits;
  };
  nginxCapabilities = [
    "CAP_NET_BIND_SERVICE"
  ]
  ++ lib.optionals config.services.nginx.enableQuicBPF [
    "CAP_SYS_ADMIN"
    "CAP_NET_ADMIN"
  ];
  applicationSandbox = shared.serviceConfig // {
    LogNamespace = "personal-storage";
    TemporaryFileSystem = [
      "/tmp:rw,size=64M,mode=1777"
      "/var/tmp:rw,size=64M,mode=1777"
    ];
    Restart = "on-failure";
    RestartSec = "5s";
    UMask = "0027";
  };
  proxy = port: {
    proxyPass = "http://127.0.0.1:${toString port}";
    recommendedProxySettings = false;
    extraConfig = ''
      proxy_http_version 1.1;
      proxy_set_header Host $host:${toString ports.https};
      proxy_set_header X-Forwarded-Host $host:${toString ports.https};
      proxy_set_header X-Forwarded-Proto https;
      proxy_set_header X-Forwarded-For $personal_storage_client_ip;
      proxy_set_header X-Real-IP $personal_storage_client_ip;
      proxy_request_buffering off;
      proxy_buffering off;
      proxy_read_timeout 1d;
      proxy_send_timeout 1d;
    '';
  };
  virtualHost = domain: {
    onlySSL = true;
    useACMEHost = domain;
    listen = shared.mkSslListen ports.https;
    extraConfig = ''
      client_max_body_size 4g;
      client_body_temp_path ${base}/nginx/body;
      proxy_temp_path ${base}/nginx/proxy;
      access_log ${base}/nginx/access.log;
      error_log ${base}/nginx/error.log warn;
    '';
  };
in
{
  options.services.personalStorage = {
    enable = lib.mkEnableOption "shared-quota LiveSync and authenticated file transfer";
    quotaGB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 35;
      description = "Shared hard quota in decimal GB; changes apply online after initial ext4 preparation.";
    };
    quotaBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = cfg.quotaGB * 1000000000;
      defaultText = lib.literalExpression "config.services.personalStorage.quotaGB * 1000000000";
      description = "Exact shared byte limit, rounded down to a 1024-byte quota block.";
    };
    transferRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Maximum age of temporary transfer files in days.";
    };
    retentionSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = cfg.transferRetentionDays * 86400;
      description = "Transfer retention in seconds; normally derived from transferRetentionDays.";
    };
    quotaMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      description = "Runtime JSON with couchdb_admin_password and livesync_password for database bootstrap.";
    };
    filesDomain = lib.mkOption {
      type = lib.types.str;
      default = "files.vps.seekerer.com";
    };
    internalFilesDomain = lib.mkOption {
      type = lib.types.str;
      default = "files-internal.vps.seekerer.com";
    };
    obsidianDomain = lib.mkOption {
      type = lib.types.str;
      default = "obsidian.vps.seekerer.com";
    };
    netbirdAddress = lib.mkOption { type = lib.types.str; };
    netbirdCIDR = lib.mkOption {
      type = lib.types.str;
      default = "100.4.0.0/16";
    };
    netbirdInterface = lib.mkOption {
      type = lib.types.str;
      default = "nb-uni-next";
    };
    netbirdUnit = lib.mkOption {
      type = lib.types.str;
      default = "netbird-uni-next.service";
    };
    sftpAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    minimumReserveBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2000000000;
    };
    compactionMarginBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1000000000;
    };
    cleanupAllowanceBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8388608;
    };
    copypartyConfigFile = lib.mkOption { type = lib.types.str; };
    couchdbAdminFile = lib.mkOption { type = lib.types.str; };
    sftpAuthorizedKeysFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/ssh/personal-storage-sftp.keys";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.openssh.enable;
        message = "personalStorage SFTP uses the host's OpenSSH PAM policy.";
      }
      {
        assertion = config.fileSystems.${cfg.quotaMountPoint}.fsType == "ext4";
        message = "personalStorage requires an ext4 quota filesystem.";
      }
      {
        assertion = cfg.minimumReserveBytes + cfg.cleanupAllowanceBytes < cfg.quotaBytes;
        message = "personalStorage quota must exceed its maintenance reserve.";
      }
    ];

    fileSystems.${cfg.quotaMountPoint}.options = lib.mkAfter [
      "usrquota"
      "prjquota"
    ];
    boot.initrd.kernelModules = [ "quota_v2" ];
    environment.etc = {
      "ssh/personal-storage-sftp.keys" = {
        text = lib.concatStringsSep "\n" cfg.sftpAuthorizedKeys;
        mode = "0444";
      };
      projects.text = "${toString projectID}:${base}\n";
      projid.text = "personal-services:${toString projectID}\n";
      "systemd/journald@personal-storage.conf".text = ''
        [Journal]
        Storage=persistent
        SystemMaxUse=64M
        RuntimeMaxUse=8M
        ForwardToSyslog=no
        ForwardToKMsg=no
        ForwardToWall=no
      '';
    };
    environment.systemPackages = [
      pkgs.quota
      (pkgs.writeShellScriptBin "personal-storage-status" "exec ${runtimeController} status")
      (pkgs.writeShellScriptBin "personal-storage-logs" ''
        machine_id=$(${pkgs.coreutils}/bin/cat /etc/machine-id)
        exec ${pkgs.systemd}/bin/journalctl --directory="${base}/journal/$machine_id.personal-storage" "$@"
      '')
    ];
    users.groups.copyparty = { };
    users.users.copyparty = {
      isSystemUser = true;
      group = "copyparty";
      home = "${base}/copyparty";
    };

    system.activationScripts.personal-storage-preflight = {
      supportsDryActivation = true;
      text = ''
        if [ -e /run/current-system ]; then
          PATH=${
            lib.makeBinPath [
              pkgs.util-linux
              pkgs.quota
            ]
          }:$PATH ${controller} preflight || exit 1
        fi
      '';
    };

    systemd.services.personal-storage-quota = {
      description = "Verify and enforce the shared personal services quota";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      unitConfig.DefaultDependencies = false;
      reloadIfChanged = true;
      path = [
        pkgs.util-linux
        pkgs.e2fsprogs
        pkgs.quota
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "personal-storage";
        RuntimeDirectoryMode = "0755";
        RuntimeDirectoryPreserve = true;
        ExecStart = "${controller} initialize";
        ExecReload = "${controller} initialize";
        CapabilityBoundingSet = [ "~CAP_SYS_RESOURCE" ];
      };
    };
    systemd.services.personal-storage-budget = {
      description = "Protect CouchDB compaction space with an online Copyparty user quota";
      wantedBy = [ "multi-user.target" ];
      requires = [ "personal-storage-quota.service" ];
      after = [ "personal-storage-quota.service" ];
      bindsTo = [ "personal-storage-quota.service" ];
      path = [
        pkgs.util-linux
        pkgs.quota
      ];
      serviceConfig = {
        ExecStart = "${runtimeController} monitor";
        LogNamespace = "personal-storage";
      };
    };
    systemd.services."systemd-journald@personal-storage" = {
      overrideStrategy = "asDropin";
      requires = [ "personal-storage-quota.service" ];
      after = [ "personal-storage-quota.service" ];
      serviceConfig = {
        LogsDirectory = lib.mkForce "";
        BindPaths = [ "${base}/journal:/var/log/journal" ];
        CapabilityBoundingSet = [ "~CAP_SYS_RESOURCE" ];
      };
    };
    systemd.services.copyparty = guardedService // {
      description = "Authenticated temporary file transfer over HTTPS";
      wantedBy = [ "multi-user.target" ];
      environment = {
        TMPDIR = "${base}/copyparty";
        XDG_CONFIG_HOME = "${base}/copyparty";
        PYTHONUNBUFFERED = "1";
      };
      serviceConfig = applicationSandbox // {
        Type = "notify";
        TimeoutStartSec = "5min";
        User = "copyparty";
        Group = "copyparty";
        WorkingDirectory = "${base}/copyparty";
        ReadWritePaths = [
          "${base}/copyparty"
          "${base}/transfer"
        ];
        ExecStart = "${lib.getExe copyparty} -c ${copypartyTemplate} -c ${cfg.copypartyConfigFile}";
      };
    };
    systemd.services.personal-storage-sftp = guardedService // {
      description = "Private OpenSSH SFTP for the transfer directory";
      wantedBy = [ "multi-user.target" ];
      wants = [ cfg.netbirdUnit ];
      after = guardedService.after ++ [ cfg.netbirdUnit ];
      preStart = ''
        if [ ! -f ${base}/sftp/host-key ]; then
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f ${base}/sftp/host-key
        fi
      '';
      serviceConfig = applicationSandbox // {
        ExecStart = "${pkgs.openssh}/bin/sshd -D -e -f ${sftpConfig}";
        BindPaths = [ "${base}/transfer:${base}/sftp/root/files" ];
        ReadWritePaths = [
          "${base}/sftp"
          "${base}/transfer"
        ];
        CapabilityBoundingSet = [ "~CAP_SYS_RESOURCE" ];
      };
    };
    systemd.services.personal-storage-expire = {
      description = "Expire transfer files using server-side creation times";
      requires = [ "personal-storage-quota.service" ];
      after = [ "personal-storage-quota.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --clean ${expiryConfig}";
        LogNamespace = "personal-storage";
        ProtectSystem = "strict";
        ReadWritePaths = [ "${base}/transfer" ];
        CapabilityBoundingSet = [ "~CAP_SYS_RESOURCE" ];
      };
    };
    systemd.timers.personal-storage-expire = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
    };

    services.couchdb = {
      enable = true;
      bindAddress = "127.0.0.1";
      port = ports.couchdb;
      databaseDir = "${base}/couchdb";
      viewIndexDir = "${base}/couchdb";
      configFile = "/run/couchdb/local.ini";
      logFile = "${base}/couchdb/couchdb.log";
      extraConfig = {
        couchdb = {
          single_node = true;
          max_document_size = 50000000;
        };
        cluster = {
          n = 1;
          q = 1;
        };
        chttpd = {
          require_valid_user = true;
          enable_cors = true;
          max_http_request_size = 4294967296;
        };
        chttpd_auth.require_valid_user = true;
        httpd.enable_cors = true;
        cors = {
          credentials = true;
          origins = "app://obsidian.md,capacitor://localhost,http://localhost";
          methods = "GET,PUT,POST,HEAD,DELETE";
          headers = "accept,authorization,content-type,origin,referer";
        };
        log = {
          writer = "stderr";
          level = "warning";
        };
        smoosh = {
          db_channels = "ratio_dbs";
          view_channels = "ratio_views";
        };
        "smoosh.ratio_dbs" = {
          concurrency = 1;
          min_priority = 1.5;
        };
        "smoosh.ratio_views" = {
          concurrency = 1;
          min_priority = 1.5;
        };
      };
    };
    systemd.services.couchdb = guardedService // {
      preStart = lib.mkBefore ''
        ${pkgs.coreutils}/bin/install -m 600 ${cfg.couchdbAdminFile} /run/couchdb/local.ini
      '';
      environment.TMPDIR = "${base}/couchdb";
      serviceConfig = applicationSandbox // {
        MemoryDenyWriteExecute = false; # Erlang's JIT requires executable mappings.
        RuntimeDirectory = "couchdb";
        ReadWritePaths = [
          "${base}/couchdb"
          "/run/couchdb"
        ];
      };
    };
    systemd.services.personal-storage-couchdb-init = {
      description = "Provision the LiveSync database and database-scoped sync account";
      wantedBy = [ "multi-user.target" ];
      requires = [ "couchdb.service" ];
      after = [ "couchdb.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${python} ${./personal-storage-couchdb.py} ${cfg.credentialsFile} ${toString ports.couchdb}";
        TimeoutStartSec = "2min";
        LogNamespace = "personal-storage";
        UMask = "0077";
      };
    };

    services.nginx = {
      enable = true;
      appendHttpConfig = ''
        geo $personal_storage_source_overlay {
          default 0;
          ${cfg.netbirdCIDR} 1;
        }
        map "$server_addr:$personal_storage_source_overlay" $personal_storage_overlay {
          default 0;
          "${cfg.netbirdAddress}:1" 1;
        }
        # The overlay uses a public-looking range. Never grant privileges to
        # a matching public source unless it reached the overlay listener.
        map "$personal_storage_overlay:$personal_storage_source_overlay" $personal_storage_client_ip {
          default $remote_addr;
          "0:1" 192.0.2.1;
        }
      '';
      virtualHosts = {
        ${cfg.filesDomain} = (virtualHost cfg.filesDomain) // {
          locations."/" = proxy ports.copyparty;
        };
        ${cfg.internalFilesDomain} = lib.recursiveUpdate (virtualHost cfg.internalFilesDomain) {
          extraConfig = (virtualHost cfg.internalFilesDomain).extraConfig + ''
            if ($personal_storage_overlay = 0) { return 403; }
          '';
          locations."/" = proxy ports.copyparty;
        };
        ${cfg.obsidianDomain} = (virtualHost cfg.obsidianDomain) // {
          locations."/" = proxy ports.couchdb;
          locations."~ ^/_(users|replicator|node|membership|cluster_setup|all_dbs|dbs_info)(/|$)".return =
            "403";
        };
      };
    };
    # Only this interface opens SFTP. HTTPS reuses the host's existing port.
    networking.firewall.interfaces.${cfg.netbirdInterface}.allowedTCPPorts = [ ports.sftp ];
    networking.firewall.allowedTCPPorts = [ ports.https ];
    services.logrotate.settings.personal-storage = {
      files = [ "${base}/nginx/*.log" ];
      frequency = "daily";
      maxsize = "8M";
      rotate = 3;
      compress = true;
      missingok = true;
      notifempty = true;
      su = "nginx nginx";
      sharedscripts = true;
      postrotate = "${pkgs.systemd}/bin/systemctl kill -s USR1 nginx.service";
    };
    # Creating/writing these paths before quota initialization is prohibited.
    # Nginx is shared with existing services, so it has no global dependency.
    systemd.services.nginx.preStart = lib.mkBefore ''
      ${pkgs.coreutils}/bin/test -d ${base}/nginx
    '';
    systemd.services.nginx.after = [ "personal-storage-quota.service" ];
    systemd.services.nginx.serviceConfig = {
      ReadWritePaths = [ "${base}/nginx" ];
      # CAP_SYS_RESOURCE bypasses disk quotas, including for log/temp writes.
      AmbientCapabilities = lib.mkForce nginxCapabilities;
      CapabilityBoundingSet = lib.mkForce nginxCapabilities;
    };
  };
}
