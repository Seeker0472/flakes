{ inputs, ... }:
let
  # gpu01 runs a standalone Home Manager setup; its build architecture and
  # "user@host" output name belong to this Home Manager entrypoint.
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
