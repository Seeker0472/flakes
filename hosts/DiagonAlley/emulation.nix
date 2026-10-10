{ ... }:

# liuqin-nixos builds its installed configurations natively for aarch64; only
# the per-machine derivations (/etc, units, initrd, images) must execute
# aarch64 tools. binfmt runs those with qemu-user here instead of cross
# compiling the whole desktop closure from source.
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
