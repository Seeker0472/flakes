{ inputs, ... }:
let
  sshKeys = import ./ssh-public-keys.nix;
in
{
  imports = [
    ../home-manager.nix
  ];

  machine.users.seeker.authorizedKeys = sshKeys.authorizedKeys;

  home-manager = {
    users.seeker = {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
        ./ai-secrets.nix
        ./home.nix
        ./ssh-secrets.nix
      ];
    };
  };
}
