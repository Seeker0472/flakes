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
        ./xdg_default.nix
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

      # Same office/media set and editors as the desktop host. obsidian, qq
      # and vscode all carry aarch64-linux builds in this nixpkgs revision
      # (checked against pkgs.meta.platforms).
      home.packages =
        (import ./packages/office.nix { inherit pkgs; })
        ++ (import ./packages/media.nix { inherit pkgs; })
        ++ (with pkgs; [
          netease-cloud-music-gtk
          obsidian
          qq
          vscode
          zotero
        ]);
    };
  };
}
