{ inputs, ... }:
{
  home-manager.users.seeker = {
    imports = [
      inputs.nixvim.homeModules.nixvim
      inputs.sops-nix.homeManagerModules.sops
      ./ai-secrets.nix
      ../../modules/profiles/programs/nixvim/default.nix
      ./home.nix
      ./ssh-secrets.nix
    ];

    machine.programs.nixvim.development.enable = true;
  };
}
