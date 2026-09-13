{
  inputs,
  system,
  overlays ? [ ],
}:
import inputs.nixpkgs {
  inherit system overlays;
  config.allowUnfree = true;
}
