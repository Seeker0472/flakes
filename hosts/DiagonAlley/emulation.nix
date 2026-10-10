{ ... }:

# liuqin-nixos builds its installed configurations natively for aarch64: the
# port's device packages (kernel, U-Boot, firmware, sensors) and the
# per-machine derivations (/etc, units, initrd, images) all execute aarch64
# tools. binfmt runs them with qemu-user here instead of cross compiling the
# closure from source. Hippogriff deploys build here by default (slow for the
# kernel); `deploy-rs --remote-build` hands the build to the tablet instead.
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
