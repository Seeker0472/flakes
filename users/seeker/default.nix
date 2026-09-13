{
  inputs,
  ...
}:
let
  sshKeys = import ./ssh-public-keys.nix;
in
{
  imports = [
    ../home-manager.nix
  ];

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
  programs.dconf.enable = true;

  machine.users.seeker.authorizedKeys = sshKeys.authorizedKeys;

  home-manager = {
    users.seeker = {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.zen-browser.homeModules.beta
        inputs.aloha.homeManagerModules.default
        ./ai-secrets.nix
        ./miLaptop.nix
      ];
    };
  };
}
