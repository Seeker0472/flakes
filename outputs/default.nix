{ ... }:
{
  imports = [
    ./nixos-configurations.nix
    ./nix-on-droid-configurations.nix
    ./home-configurations.nix
    ./deploy.nix
    ./checks.nix
    ./devshell.nix
    ./dev-container-image.nix
    ./clients.nix
  ];
}
