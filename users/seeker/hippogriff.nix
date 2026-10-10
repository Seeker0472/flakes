{ inputs, pkgs, ... }:
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
      # The dev-machine profile: identity/tooling, the shared secrets, and
      # the interactive app set requested for the tablet, without the desktop
      # host's window-manager configuration.
      imports = [
        inputs.zen-browser.homeModules.beta
        ./hm-base.nix
        ./home.nix
        ./ssh-secrets.nix
        ./taskwarrior-sync.nix
        ../../modules/profiles/programs/home/kitty.nix
        ../../modules/profiles/programs/home/zed.nix
        ../../modules/home/kde-connect.nix
        ../../modules/profiles/input/fcitx5.nix
      ];

      programs = {
        taskwarrior.enable = true;
        kitty.enable = true;
        zen-browser.enable = true;
      };

      # Office/document tools plus the players and reference apps from the
      # desktop host's list. obsidian, qq and vscode are x86_64-linux only in
      # nixpkgs; the editor/recorder set from packages/media.nix (obs-studio,
      # gimp, ...) stays out by request.
      home.packages =
        (import ./packages/office.nix { inherit pkgs; })
        ++ (with pkgs; [
          mpv
          netease-cloud-music-gtk
          zotero
        ]);
    };
  };
}
