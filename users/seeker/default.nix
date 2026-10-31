{
  inputs,
  ...
}:
{
  imports = [
    ./account.nix
  ];

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
  programs.dconf.enable = true;

  home-manager = {
    users.seeker = {
      imports = [
        inputs.zen-browser.homeModules.beta
        inputs.aloha.homeManagerModules.default
        ./hm-base.nix
        ./desktop-host.nix
      ];
    };
  };
}
