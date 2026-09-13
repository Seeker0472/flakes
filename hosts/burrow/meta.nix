{
  system = "x86_64-linux";
  hostName = "burrow";
  stateVersion = "26.05";

  machine = {
    type = "server";
    cpu = "intel";

    users.seeker.enable = true;

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

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
      openFirewall = true;
    };
  };
}
