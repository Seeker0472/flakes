{ inputs, ... }:
{
  imports = [
    ./development.nix
    # The disko NixOS module provides the disko.* options consumed by
    # single-disk.nix; kept here until the profile owns its flake input
    # (out of this scope).
    inputs.disko.nixosModules.disko
    ../profiles/programs/mihomo/mihomo.nix
    ../profiles/programs/netbird.nix
    ../profiles/system/storage/single-disk.nix
  ];
}
