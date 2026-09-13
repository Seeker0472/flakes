{ inputs, ... }:
{
  imports = [
    ./base-cli.nix
    ../profiles/system/core/networkmanager.nix
    ../profiles/system/dev/default.nix
    ../profiles/programs/nixvim/default.nix
    # nixvim's NixOS module provides programs.nixvim; kept next to the profile
    # until the profile directory owns its flake input (out of this scope).
    inputs.nixvim.nixosModules.nixvim
  ];
}
