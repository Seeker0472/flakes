{ inputs, ... }:
{
  # Common Home Manager module imports shared by every seeker host profile.
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ./ai-secrets.nix
  ];
}
