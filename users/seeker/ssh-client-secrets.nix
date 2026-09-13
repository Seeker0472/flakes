{ config, lib, ... }:
let
  helpers = import ./ssh-key-pair.nix { inherit config lib; };
  inherit (helpers) mkKeyPair;
in
{
  programs.ssh.settings = {
    "*" = {
      IdentityFile = [ config.sops.secrets."ssh-external-private".path ];
      IdentitiesOnly = true;
    };
    "github.com" = {
      IdentityFile = [ config.sops.secrets."ssh-github-private".path ];
      IdentitiesOnly = true;
    };
  };

  sops.secrets = mkKeyPair "ssh-external" "external" // mkKeyPair "ssh-github" "github";
}
