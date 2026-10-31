{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkMerge [
    (lib.mkIf config.virtualisation.virtualbox.host.enable {
      users.extraGroups.vboxusers.members = [ config.machine.mainUser ];
    })
    (lib.mkIf config.virtualisation.docker.enable {
      virtualisation.docker = {
        rootless.setSocketVariable = true;
      };
    })
    (lib.mkIf config.virtualisation.libvirtd.enable (
      let
        persistentStateMounts = [
          "/var/lib/systemd"
          "/var/lib/libvirt"
        ];
      in
      {
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
