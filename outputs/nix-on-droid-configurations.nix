{ inputs, ... }:
let
  system = "aarch64-linux";
  pkgs = import ./common/mk-pkgs.nix {
    inherit inputs system;
    overlays = [ inputs.nix-on-droid.overlays.default ];
  };

  mkDroid =
    deviceModule:
    inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ../hosts/nixOnDroid/common.nix
        deviceModule
      ];
    };
in
{
  flake.nixOnDroidConfigurations = {
    mi15 = mkDroid ../hosts/nixOnDroid/mi15.nix;
    miPad = mkDroid ../hosts/nixOnDroid/miPad.nix;
  };
}
