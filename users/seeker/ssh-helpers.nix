{
  config,
  lib,
}:
let
  sshKeys = import ./ssh-public-keys.nix;
  meshHost = user: {
    User = user;
    IdentityFile = [ config.sops.secrets."ssh-client-private".path ];
    IdentitiesOnly = true;
  };
in
{
  inherit sshKeys meshHost;

  meshHosts = {
    DiagonAlley = meshHost "seeker";
    miLaptop = meshHost "seeker";
    devVM = meshHost "seeker";
    nixos-wsl = meshHost "seeker";
    ecos = meshHost "seeker4721";
    transfer = (meshHost "copyparty") // {
      HostName = "files-internal.vps.seekerer.com";
      Port = 2222;
    };
  };

  # Declare a matching private/public sops secret pair for an SSH key.
  # `name` is the secret-name prefix; the file is registered under
  # `identity` in ssh-public-keys.nix.
  mkKeyPair =
    name: identity:
    let
      home = config.home.homeDirectory;
      fileName = if name == "ssh-client" then "id_mesh" else "id_${lib.removePrefix "ssh-" name}";
    in
    {
      "${name}-private" = {
        sopsFile = sshKeys.files.${identity};
        key = "private_key";
        path = "${home}/.ssh/${fileName}";
        mode = "0600";
      };
      "${name}-public" = {
        sopsFile = sshKeys.files.${identity};
        key = "public_key_unencrypted";
        path = "${home}/.ssh/${fileName}.pub";
        mode = "0644";
      };
    };
}
