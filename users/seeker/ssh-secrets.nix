{
  config,
  lib,
  osConfig,
  ...
}:
let
  hostName = osConfig.networking.hostName;
  helpers = import ./ssh-key-pair.nix { inherit config lib; };
  inherit (helpers) mkKeyPair sshKeys;
  clientSopsFile = sshKeys.files.${hostName} or null;
  deploySecrets = lib.attrByPath [ "machine" "secrets" "deploy" ] false osConfig;
  ageKeyPath = lib.attrByPath [ "machine" "secrets" "ageKeyPath" ] null osConfig;
  isAdminHost = builtins.elem hostName [
    "DiagonAlley"
    "miLaptop"
    "nixos-wsl"
  ];
  meshHost = user: {
    User = user;
    IdentityFile = [ config.sops.secrets."ssh-client-private".path ];
    IdentitiesOnly = true;
  };
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

    programs.ssh.settings = {
      DiagonAlley = meshHost "seeker";
      miLaptop = meshHost "seeker";
      devVM = meshHost "seeker";
      nixos-wsl = meshHost "seeker";
      ecos = meshHost "seeker4721";
    }
    // lib.optionalAttrs isAdminHost {
      "vps.seekerer.com" = {
        IdentityFile = [ config.sops.secrets."ssh-admin-private".path ];
        IdentitiesOnly = true;
      };
    };

    sops = {
      age.keyFile = ageKeyPath;
      secrets = {
        "ssh-client-private" = {
          sopsFile = clientSopsFile;
          key = "private_key";
          path = "${config.home.homeDirectory}/.ssh/id_mesh";
          mode = "0600";
        };
        "ssh-client-public" = {
          sopsFile = clientSopsFile;
          key = "public_key_unencrypted";
          path = "${config.home.homeDirectory}/.ssh/id_mesh.pub";
          mode = "0644";
        };
      }
      // lib.optionalAttrs isAdminHost (mkKeyPair "ssh-admin" "admin");
    };
  };
}
