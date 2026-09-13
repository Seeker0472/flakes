{ inputs, ... }:
{
  imports = [
    ./base-system.nix
    inputs.home-manager.nixosModules.home-manager
    ../../users/home-manager.nix
    ../profiles/system/hardware/users.nix
    ../profiles/system/hardware/user-accounts.nix
  ];
}
