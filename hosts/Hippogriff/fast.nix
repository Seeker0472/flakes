# Daily builds inject the port's x86_64 -> aarch64 device packages. The
# default profile keeps native packages so the tablet can rebuild its boot chain.
{ inputs, lib, ... }:
{
  imports = [ ./default.nix ];
  nixpkgs.overlays = lib.mkAfter [
    (import (inputs.liuqin.outPath + "/overlay-inject.nix") {
      pkgsArm = inputs.liuqin.lib.pkgsArm;
    })
  ];
}
