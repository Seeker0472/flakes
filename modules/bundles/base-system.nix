{ inputs, ... }:
{
  imports = [
    ../default.nix
    inputs.sops-nix.nixosModules.sops
    ../profiles/system/core/common.nix
    ../profiles/system/core/networking.nix
    ../profiles/system/core/openssh.nix
    ../profiles/secrets/sops.nix
    ../profiles/secrets/nix-config.nix
    ../profiles/secrets/webdav.nix
    # Hardware profiles are machine.cpu / machine.type conditional, so they are
    # imported for every host and activate themselves.
    ../profiles/system/hardware/intel.nix
    ../profiles/system/hardware/laptop.nix
  ];
}
