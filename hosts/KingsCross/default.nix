import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    ./netbird.nix
    ./secrets.nix
    ./taskchampion.nix
    (
      {
        inputs,
        lib,
        pkgs,
        ...
      }:
      let
        sshKeys = import ../../users/seeker/ssh-public-keys.nix;
        adminSshKeys = [ sshKeys.admin ];
      in
      {
        imports = [
          inputs.nixvim.nixosModules.nixvim
          ../../modules/profiles/programs/nixvim/default.nix
        ];

        networking = {
          useDHCP = lib.mkDefault true;
          dhcpcd.extraConfig = "noarp";

          firewall = {
            # Reserved band for ad-hoc services on the VPS: 28400-28499 (TCP and
            # UDP) stays open so temporary tools can be started without another
            # rebuild. Persistent services still declare their own ports in
            # their modules (netbird.nix, taskchampion.nix).
            allowedTCPPortRanges = [
              {
                from = 28400;
                to = 28499;
              }
            ];
            allowedUDPPortRanges = [
              {
                from = 28400;
                to = 28499;
              }
            ];
          };
        };

        boot.initrd.availableKernelModules = [
          "ata_piix"
          "uhci_hcd"
          "virtio_pci"
          "virtio_scsi"
          "sd_mod"
          "sr_mod"
        ];

        services = {
          openssh = {
            enable = true;
            openFirewall = true;
            settings = {
              KbdInteractiveAuthentication = false;
              PasswordAuthentication = false;
              PermitRootLogin = "prohibit-password";
            };
          };
          qemuGuest.enable = true;
        };

        programs = {
          fish.enable = true;
          nixvim = {
            defaultEditor = true;
            viAlias = true;
            vimAlias = true;
          };
        };

        users = {
          mutableUsers = false;
          users = {
            root = {
              hashedPassword = "!";
              openssh.authorizedKeys.keys = adminSshKeys;
            };
            seeker = {
              isNormalUser = true;
              uid = 1000;
              description = "Seeker";
              extraGroups = [ "wheel" ];
              hashedPassword = "!";
              shell = pkgs.fish;
              openssh.authorizedKeys.keys = adminSshKeys;
            };
          };
        };
        security.sudo.wheelNeedsPassword = false;

        environment.defaultPackages = lib.mkForce [ ];
        environment.systemPackages = [
          pkgs.btop
          pkgs.fd
          pkgs.file
          pkgs.htop
          pkgs.jq
          pkgs.less
          pkgs.mtr
          pkgs.ncdu
          pkgs.ripgrep
          pkgs.rsync
          pkgs.tmux
          pkgs.tree
          pkgs.unzip
          pkgs.zip
        ];
        documentation.enable = false;
        programs.command-not-found.enable = false;

        nix = {
          channel.enable = false;
          settings = {
            connect-timeout = 10;
            fallback = true;
            substituters = lib.mkForce [
              "https://mirrors.ustc.edu.cn/nix-channels/store"
              "https://cache.nixos.org"
            ];
          };
        };

        time.timeZone = "Asia/Shanghai";
      }
    )
  ];
}
