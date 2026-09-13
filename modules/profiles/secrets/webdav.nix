{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.machine.secrets.webdav;
in
{
  options.machine.secrets.webdav = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WebDAV remote mounting";
    };
    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "123PAN";
      description = "Rclone remote name to mount";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments for rclone mount";
    };
    mountPoint = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/123PAN";
      description = "Mount point for the WebDAV remote";
    };
  };
  config = lib.mkIf (cfg.enable && config.machine.secrets.deploy) {
    sops.secrets."rclone" = {
      sopsFile = ./sys.secrets.yaml;
      key = "rclone_conf";
      owner = "root";
      group = "root";
      mode = "600";
      restartUnits = [ "rclone-webdav.service" ];
      # this is the path where the secret will be mounted
      path = "/etc/rclone/rclone.conf";
    };

    systemd.services.rclone-webdav = {
      description = "Rclone Mount for WebDAV ( 123PAN )";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "sops-nix.service"
      ];
      requires = [ "sops-nix.service" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";

        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.mountPoint}";

        ExecStart =
          let
            args = [
              "--config"
              "/etc/rclone/rclone.conf"
              "--allow-other"
              "--vfs-cache-mode"
              "full"
              "--log-level"
              "INFO"
            ]
            ++ cfg.extraArgs
            ++ [
              "${cfg.remoteName}:"
              (toString cfg.mountPoint)
            ];
          in
          "${pkgs.rclone}/bin/rclone mount ${lib.escapeShellArgs args}";

        ExecStop = "${pkgs.fuse}/bin/fusermount -u ${cfg.mountPoint}";
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
}
