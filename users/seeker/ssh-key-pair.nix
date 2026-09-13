{
  config,
  lib,
}:
let
  sshKeys = import ./ssh-public-keys.nix;
in
{
  inherit sshKeys;

  # Declare a matching private/public sops secret pair for an SSH key.
  # `name` is the secret-name prefix; the file is registered under
  # `identity` in ssh-public-keys.nix.
  mkKeyPair =
    name: identity:
    let
      home = config.home.homeDirectory;
    in
    {
      "${name}-private" = {
        sopsFile = sshKeys.files.${identity};
        key = "private_key";
        path = "${home}/.ssh/id_${lib.removePrefix "ssh-" name}";
        mode = "0600";
      };
      "${name}-public" = {
        sopsFile = sshKeys.files.${identity};
        key = "public_key_unencrypted";
        path = "${home}/.ssh/id_${lib.removePrefix "ssh-" name}.pub";
        mode = "0644";
      };
    };
}
