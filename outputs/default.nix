{ ... }:
{
  imports = [
    ./nixos-configurations.nix
    ./nix-on-droid-configurations.nix
    ./home-configurations.nix
    ./devshell.nix
    ./dev-container-image.nix
  ];
}
