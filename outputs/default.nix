{ ... }:
{
  imports = [
    ./nixos-configurations.nix
    ./nix-on-droid-configurations.nix
    ./home-configurations.nix
    ./deploy.nix
    ./devshell.nix
    ./dev-container-image.nix
  ];
}
