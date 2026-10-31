{ pkgs, ... }:
{
  imports = [
    ../../modules/bundles/desktop.nix
    ../../users/seeker
    ./disk.nix
    ./hardware-configuration.nix
    ./xbox-firmware-overlay.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "miLaptop";
  system.stateVersion = "24.05";

  machine = {
    type = "laptop";
    cpu = "intel";
    impermanence.enable = true;

    de = {
      niri.enable = true;
    };

    programs = {
      kdeconnect.enable = true;
      mihomo = {
        enable = true;
        share.enable = true;
        tun.enable = true;
        web.enable = true;
      };
      netbird.enable = true;
      nixvim.development.enable = true;
    };

    secrets = {
      deploy = true;
      nixConfig.enable = true;
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  virtualisation = {
    docker.enable = true;
    virtualbox.host.enable = true;
  };

  programs = {
    gnupg.agent.enable = true;
    steam.enable = true;
    thunar.enable = true;
  };

  home-manager.users.seeker.programs.zed-editor.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_PATH}=="platform-i8042-serio-0", RUN+="${pkgs.kbd}/bin/setkeycodes e072 183"
  '';

  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.systembus-notify.enable = true;
  };

  environment.systemPackages = [ pkgs.smartmontools ];

  # deploy-rs pushes the closure over the ssh-ng store; the machine user
  # must be allowed to import unsigned paths (nixpkgs trusts root only).
  nix.settings.trusted-users = [
    "root"
    "seeker"
  ];
}
