{
  imports = [
    ../../modules/bundles/desktop.nix
    ../../users/seeker
    ./disk.nix
    ./fancontrol
    ./hardware-configuration.nix
    ../miLaptop/xbox-firmware-overlay.nix
    ./it87.nix
    ./emulation.nix
    ./openrgb
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "DiagonAlley";
  system.stateVersion = "26.05";

  machine = {
    type = "desktop";
    cpu = "amd";
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
      # The identity is installed into /persist during the Live ISO install.
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
    libvirtd.enable = true;
    virtualbox.host.enable = true;
  };

  programs = {
    gnupg.agent.enable = true;
    steam.enable = true;
    thunar.enable = true;
  };

  home-manager.users.seeker.programs.zed-editor.enable = true;

  services.tailscale.enable = true;
}
