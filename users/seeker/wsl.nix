{ inputs, ... }:
{
  home-manager.users.seeker = {
    imports = [
      inputs.nixvim.homeModules.nixvim
      ../../modules/profiles/programs/nixvim/default.nix
      ./hm-base.nix
      ./home.nix
      ./ssh-secrets.nix
    ];

    machine.programs.nixvim.development.enable = true;
  };
}
