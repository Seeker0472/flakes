{
  config,
  lib,
  osConfig,
  ...
}:
let
  hostName = osConfig.networking.hostName;
  helpers = import ./ssh-helpers.nix { inherit config lib; };
  inherit (helpers) mkKeyPair sshKeys;
  clientSopsFile = sshKeys.files.${hostName} or null;
  deploySecrets = lib.attrByPath [ "machine" "secrets" "deploy" ] false osConfig;
  ageKeyPath = lib.attrByPath [ "machine" "secrets" "ageKeyPath" ] null osConfig;
  isAdminHost = builtins.elem hostName [
    "DiagonAlley"
    "miLaptop"
    "nixos-wsl"
    "Hippogriff"
  ];
in
{
  imports = lib.optional deploySecrets ./ssh-client-secrets.nix;

  config = lib.mkIf deploySecrets {
    assertions = [
      {
        assertion = clientSopsFile != null;
        message = "No SSH client SOPS file is registered for ${hostName}.";
      }
      {
        assertion = ageKeyPath != null;
        message = "machine.secrets.ageKeyPath is required to deploy SSH keys on ${hostName}.";
      }
    ];

    programs.ssh.settings =
      helpers.meshHosts
      // {
        Hippogriff = helpers.meshHost "seeker";
      }
      // lib.optionalAttrs isAdminHost {
        "vps.seekerer.com" = {
          IdentityFile = [ config.sops.secrets."ssh-admin-private".path ];
          IdentitiesOnly = true;
        };
      };

    sops = {
      age.keyFile = ageKeyPath;
      secrets =
        mkKeyPair "ssh-client" hostName // lib.optionalAttrs isAdminHost (mkKeyPair "ssh-admin" "admin");
    };
  };
}
