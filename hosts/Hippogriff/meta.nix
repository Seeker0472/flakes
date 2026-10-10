{
  system = "aarch64-linux";
  hostName = "Hippogriff";
  stateVersion = "26.11";

  machine = {
    # The Xiaomi Pad 6 Pro is neither a PC laptop nor a desktop: the
    # Qualcomm device module owns power, input, display and audio, so the
    # laptop profile's TLP/keyd stack stays off.
    type = "others";
    cpu = "others";

    users = {
      seeker = {
        enable = true;
        # Same groups as miLaptop.
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "audio"
          "video"
          "input"
          "disk"
          "dialout"
          "i2c"
        ];
      };
    };

    programs = {
      nixvim.development.enable = true;
      gnome-keyring.enable = true;
      # The dev-machine program set requested for this tablet.
      kdeconnect.enable = true;
      mihomo = {
        enable = true;
        share.enable = true;
        tun.enable = true;
        web.enable = true;
      };
      netbird.enable = true;
      zed.enable = true;
      gpg.enable = true;
    };

    virtualization.docker.enable = true;

    secrets = {
      deploy = true;
      nixConfig.enable = true;
    };

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
      openFirewall = true;
    };
  };
}
