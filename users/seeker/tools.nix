{ lib, pkgs, ... }:
{
  home.packages =
    (import ./packages/base.nix { inherit pkgs; })
    ++ (import ./packages/dev.nix { inherit pkgs; })
    ++ [ (pkgs.java-wayland or pkgs.zulu17) ];

  home.sessionVariables = lib.optionalAttrs (pkgs ? java-wayland) {
    JAVA_HOME = pkgs.java-wayland.home;
  };
}
