{ inputs, ... }:
let
  # gpu01 runs a standalone Home Manager setup; it has no meta.nix, so the
  # architecture and the "user@host" attribute live here next to the config.
  system = "x86_64-linux";
  gpuUser = "seeker4721";
  gpuHost = "gpu01";
  pkgs = import ./common/mk-pkgs.nix { inherit inputs system; };
in
{
  flake.homeConfigurations."${gpuUser}@${gpuHost}" =
    inputs.home-manager.lib.homeManagerConfiguration
      {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          inputs.nixvim.homeModules.nixvim
          inputs.sops-nix.homeManagerModules.sops
          ../modules/profiles/programs/nixvim/default.nix
          ../users/seeker/ai-secrets.nix
          ../users/seeker/home.nix
          ../hosts/gpu01/home.nix
        ];
      };
}
