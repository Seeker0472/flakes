{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ./home.nix
    ./ai-secrets.nix
    ./nix-on-droid-ssh.nix
  ];
}
