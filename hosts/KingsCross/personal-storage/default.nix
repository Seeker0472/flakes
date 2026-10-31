{ config, lib, ... }:
let
  cfg = config.services.personalStorage;
  shared = import ../service-helpers.nix;
  sshKeys = import ../../../users/seeker/ssh-public-keys.nix;
  credentialKeys = [
    "transfer_password"
    "manager_password"
    "couchdb_admin_password"
    "livesync_password"
  ];
in
{
  imports = [ ./service.nix ];

  services.personalStorage = {
    enable = true;
    quotaGB = 35;
    transferRetentionDays = 3;
    netbirdAddress = "100.4.16.88";
    sftpAuthorizedKeys = sshKeys.authorizedKeys;
    copypartyConfigFile = config.sops.templates."personal-storage-copyparty.conf".path;
    couchdbAdminFile = config.sops.templates."personal-storage-couchdb.ini".path;
    credentialsFile = config.sops.templates."personal-storage.json".path;
  };

  sops = {
    secrets = lib.genAttrs credentialKeys (_: {
      sopsFile = ../personal-storage.secrets.yaml;
      mode = "0400";
    });
    templates = {
      "personal-storage-copyparty.conf" = {
        owner = "copyparty";
        mode = "0400";
        restartUnits = [ "copyparty.service" ];
        content = ''
          [accounts]
            transfer: ${config.sops.placeholder.transfer_password}
            manager: ${config.sops.placeholder.manager_password}
        '';
      };
      "personal-storage-couchdb.ini" = {
        owner = "couchdb";
        mode = "0400";
        restartUnits = [
          "couchdb.service"
          "personal-storage-couchdb-init.service"
        ];
        content = ''
          [admins]
          admin = ${config.sops.placeholder.couchdb_admin_password}
        '';
      };
      "personal-storage.json" = {
        mode = "0400";
        restartUnits = [ "personal-storage-couchdb-init.service" ];
        # Preserve the credential bundle consumed by the previous generation.
        content = builtins.toJSON (lib.genAttrs credentialKeys (name: config.sops.placeholder.${name}));
      };
    };
  };

  security.acme.certs = lib.genAttrs [ cfg.filesDomain cfg.internalFilesDomain cfg.obsidianDomain ] (
    _: shared.mkAlidnsCert { inherit config; }
  );
}
