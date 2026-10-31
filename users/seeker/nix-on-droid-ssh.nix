{ config, lib, ... }:
let
  helpers = import ./ssh-helpers.nix { inherit config lib; };
  inherit (helpers) mkKeyPair;
  home = config.home.homeDirectory;
in
{
  # Reuse the miLaptop identity so both Android devices have the same outbound
  # SSH access. The age key must be provisioned on each device separately.
  sops.age.keyFile = "${home}/.config/sops/age/keys.txt";

  programs.ssh.settings = helpers.meshHosts // {
    "*" = {
      IdentityFile = [ config.sops.secrets."ssh-external-private".path ];
      IdentitiesOnly = true;
    };
    "vps.seekerer.com" = {
      IdentityFile = [ config.sops.secrets."ssh-admin-private".path ];
      IdentitiesOnly = true;
    };
  };

  sops.secrets =
    mkKeyPair "ssh-client" "miLaptop"
    // mkKeyPair "ssh-external" "external"
    // mkKeyPair "ssh-github" "github"
    // mkKeyPair "ssh-admin" "admin";
}
