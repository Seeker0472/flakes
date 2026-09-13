{
  inputs,
  pkgs,
  ...
}:
let
  sshKeys = import ./ssh-public-keys.nix;
in
{
  imports = [ ../home-manager.nix ];

  machine.users.seeker.authorizedKeys = sshKeys.authorizedKeys;

  programs.fish.enable = true;
  users.users.seeker.shell = pkgs.fish;

  home-manager.users.seeker =
    { config, lib, ... }:
    let
      helpers = import ./ssh-key-pair.nix { inherit config lib; };
    in
    {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
        ./home.nix
      ];

      programs.ssh.settings."vps.seekerer.com" = {
        IdentityFile = [ "${config.home.homeDirectory}/.ssh/id_admin" ];
        IdentitiesOnly = true;
      };

      sops = {
        age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        secrets = helpers.mkKeyPair "ssh-admin" "admin";
      };
    };
}
