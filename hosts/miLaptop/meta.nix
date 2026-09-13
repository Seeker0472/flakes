{
  system = "x86_64-linux";
  hostName = "miLaptop";
  stateVersion = "24.05";

  machine = {
    type = "laptop";
    cpu = "intel";
    impermanence.enable = true;

    de = {
      niri.enable = true;
      quickshell.enable = true;
      wofi.enable = true;
      wpaperd.enable = true;
    };

    users = {
      seeker.enable = true;
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
      zed.enable = true;
      gpg.enable = true;
      thunar.enable = true;
      steam.enable = true;
    };

    secrets = {
      deploy = true;
      nixConfig.enable = true;
    };

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
      openFirewall = true;
    };

    virtualization = {
      docker.enable = true;
      virtualbox.enable = true;
    };
  };

}
