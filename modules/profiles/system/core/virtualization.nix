{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.machine.virtualization = {
    virtualbox = {
      enable = lib.mkEnableOption "VirtualBox";
    };
    docker = {
      enable = lib.mkEnableOption "Docker";
    };
    libvirt = {
      enable = lib.mkEnableOption "libvirt with QEMU";
    };
  };
  config = lib.mkMerge [
    (lib.mkIf config.machine.virtualization.virtualbox.enable {
      virtualisation.virtualbox.host.enable = true;
      users.extraGroups.vboxusers.members = [ config.machine.mainUser ];
    })
    (lib.mkIf config.machine.virtualization.docker.enable {
      virtualisation.docker = {
        enable = true;
        # speed-up boot process ,maybe `--restart=always` won't work
        # enableOnBoot = false;
        rootless.setSocketVariable = true;
        #daemon.settings = { data-root = "/etc/docker"; };
      };
    })
    (lib.mkIf config.machine.virtualization.libvirt.enable (
      let
        persistentStateMounts = [
          "/var/lib/systemd"
          "/var/lib/libvirt"
        ];
      in
      {
        virtualisation.libvirtd.enable = true;
        virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];
        programs.virt-manager.enable = true;

        # Both libvirt's encrypted secret and systemd's host key live in
        # persistent state on this impermanent host.
        systemd.services.virt-secret-init-encryption.unitConfig.RequiresMountsFor = persistentStateMounts;
        systemd.services.libvirtd.unitConfig.RequiresMountsFor = persistentStateMounts;

        users.extraGroups.libvirtd.members = [ config.machine.mainUser ];

        environment.systemPackages = with pkgs; [
          dnsmasq
          libguestfs
          qemu
        ];
      }
    ))
  ];
}
