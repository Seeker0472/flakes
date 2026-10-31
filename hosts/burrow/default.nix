{
  imports = [
    ../../modules/bundles/gateway.nix
    ../../users/seeker/burrow.nix
    ./disk.nix
    ./hardware-configuration.nix
    ./networking.nix
    {
      programs.nixvim = {
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
      };
    }
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "burrow";
  system.stateVersion = "26.05";

  machine = {
    type = "server";
    cpu = "intel";

    programs = {
      mihomo = {
        enable = true;
        share = {
          enable = true;
          openFirewall = false;
          allowedCIDRs = [
            "127.0.0.0/8"
            "::1/128"
            "192.168.3.0/24"
          ];
        };
        tun.enable = true;
        web.enable = true;
      };
      netbird.enable = true;
      nixvim.enable = true;
    };

    secrets = {
      deploy = true;
    };

  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };
}
