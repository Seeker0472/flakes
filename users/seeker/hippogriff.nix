{ ... }:
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

  machine.users.seeker.authorizedKeys = sshKeys.authorizedKeys ++ [
    # Deployment key in day-to-day use on the tablet since the port demo
    # (/home/seeker/.ssh/id_liuqin.pub). Keep it while the sops-managed keys
    # settle in; drop it once the admin/client keys are in use everywhere.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEmzXtiVemck1Ox+0QAL59sntUP4EULCZdHif4oDo7IX seeker@liuqin"
  ];

  home-manager = {
    users.seeker = {
      # The dev-machine profile: identity/tooling and the shared secrets,
      # without the desktop host's window-manager and media package set.
      imports = [
        ./hm-base.nix
        ./home.nix
        ./ssh-secrets.nix
        ./taskwarrior-sync.nix
      ];

      programs.taskwarrior.enable = true;
    };
  };
}
