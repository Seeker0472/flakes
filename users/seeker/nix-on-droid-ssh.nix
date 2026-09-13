{ config, lib, ... }:
let
  helpers = import ./ssh-key-pair.nix { inherit config lib; };
  inherit (helpers) mkKeyPair;
  home = config.home.homeDirectory;
  meshHost = user: {
    User = user;
    IdentityFile = [ config.sops.secrets."ssh-client-private".path ];
    IdentitiesOnly = true;
  };
in
{
  # Reuse the miLaptop identity so both Android devices have the same outbound
  # SSH access. The age key must be provisioned on each device separately.
  sops.age.keyFile = "${home}/.config/sops/age/keys.txt";

  programs.ssh.settings = {
    "*" = {
      IdentityFile = [ config.sops.secrets."ssh-external-private".path ];
      IdentitiesOnly = true;
    };
    DiagonAlley = meshHost "seeker";
    miLaptop = meshHost "seeker";
    devVM = meshHost "seeker";
    nixos-wsl = meshHost "seeker";
    ecos = meshHost "seeker4721";
    "vps.seekerer.com" = {
      IdentityFile = [ config.sops.secrets."ssh-admin-private".path ];
      IdentitiesOnly = true;
    };
  };

  sops.secrets = {
    "ssh-client-private" = {
      sopsFile = helpers.sshKeys.files.miLaptop;
      key = "private_key";
      path = "${home}/.ssh/id_mesh";
      mode = "0600";
    };
    "ssh-client-public" = {
      sopsFile = helpers.sshKeys.files.miLaptop;
      key = "public_key_unencrypted";
      path = "${home}/.ssh/id_mesh.pub";
      mode = "0644";
    };
  }
  // mkKeyPair "ssh-external" "external"
  // mkKeyPair "ssh-github" "github"
  // mkKeyPair "ssh-admin" "admin";
}
