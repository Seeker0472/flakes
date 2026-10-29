{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.clash-verge-willow = import ../packages/clash-verge-willow.nix { inherit pkgs; };
    };
}
