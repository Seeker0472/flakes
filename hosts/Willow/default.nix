import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    ../lib/vps-base.nix
    ../../modules/profiles/programs/netbird.nix
    ./mihomo.nix
  ];
}
