{ inputs, pkgs, ... }:
{
  imports = [
    ../../modules/bundles/tablet.nix
    ../../users/seeker/hippogriff.nix
    inputs.liuqin.nixosModules.liuqin
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.config.allowUnfreePredicate = inputs.liuqin.lib.allowLiuqinUnfree;
  networking.hostName = "Hippogriff";
  system.stateVersion = "26.11";

  machine = {
    # The Xiaomi Pad 6 Pro is neither a PC laptop nor a desktop: the
    # Qualcomm device module owns power, input, display and audio, so the
    # laptop profile's TLP/keyd stack stays off.
    type = "others";
    cpu = "others";

    programs = {
      nixvim.development.enable = true;
      # The dev-machine program set requested for this tablet.
      kdeconnect.enable = true;
      mihomo = {
        enable = true;
        share.enable = true;
        tun.enable = true;
        web.enable = true;
      };
      netbird.enable = true;
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

  virtualisation.docker.enable = true;

  programs = {
    gnupg.agent.enable = true;
    # The tablet's terminal (GNOME Console) spawns the account login shell
    # unless a custom command is configured, so make fish that shell; this
    # also registers fish in /etc/shells.
    fish.enable = true;
  };

  users.users.seeker.shell = pkgs.fish;

  home-manager.users.seeker.programs.zed-editor.enable = true;

  services.gnome.gnome-keyring.enable = true;

  # Xiaomi Pad 6 Pro (liuqin, SM8475): the port flake (flake.nix
  # `liuqin` input) provides the kernel, firmware, device packages and
  # every hardware.liuqin.* option this module consumes.
  hardware.liuqin = {
    enable = true;
    # Wi-Fi SSH is the debug path; the unauthenticated USB root shell
    # stays off on a daily machine (the RAM installer keeps its own).
    debugTransport = "ssh";
    boot.loader = "uboot";
    storage.layout = "linux-partition";

    desktop.gnome = {
      enable = true;
      sessionUser = "seeker";
    };

    camera = {
      enable = true;
      autofocus.enable = true;
    };
    fingerprint.enable = true;
    mipps.enable = true;
  };

  # ssh-ng:// store deployments from the build host (nix copy) need
  # the machine user to be trusted by the local daemon.
  nix.settings.trusted-users = [
    "root"
    "seeker"
  ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Audio inspection tools plus the three device-specific GNOME Quick
  # Settings extensions shipped by the port.
  environment.systemPackages = [
    pkgs.alsa-utils
    pkgs.liuqinGnomeFlashlight
    pkgs.liuqinGnomeKeyboardBacklight
    pkgs.liuqinGnomeAutoBrightness
  ];

  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/shell".enabled-extensions = [
        "liuqin-flashlight@liuqin"
        "liuqin-keyboard-backlight@liuqin"
        "liuqin-autobrightness@liuqin"
      ];
    }
  ];

  hardware.i2c.enable = true;
  zramSwap.enable = true;

  # The port ships Noto CJK, but the fontconfig defaults still resolve
  # to DejaVu: no CJK metrics for plain sans-serif/monospace requests
  # and no Nerd Font glyphs (kitty, zed). Mirror the laptop profile's
  # defaults; emoji falls back to Noto Colour Emoji instead of
  # JoyPixels, whose nixpkgs licence flag is not accepted here.
  fonts = {
    packages = [
      pkgs.sarasa-gothic # 更纱黑体
      pkgs.maple-mono.NF-CN
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans CJK SC" ];
      serif = [ "Noto Serif CJK SC" ];
      monospace = [ "Maple Mono NF CN" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Input method: the laptop profile carries this block for PC laptops;
  # the tablet's machine.type is "others", so it is stated here.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      kdePackages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
  };
}
