{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
in
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        devContainerImage = import ../packages/dev-container-image.nix {
          inherit inputs;
          pkgs = import ./common/mk-pkgs.nix { inherit inputs system; };
        };
      };
    };
}
