{ inputs, ... }:
{
  imports = [
    ./base-system.nix
    inputs.home-manager.nixosModules.home-manager
    ../../users/home-manager.nix
    ../profiles/system/core/accounts.nix
    ../profiles/system/core/openssh.nix
  ];
}
