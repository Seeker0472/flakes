{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;

  mkNixos =
    {
      system,
      modules,
      baseModules,
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = baseModules ++ modules;
    };

  hosts = {
    miLaptop = {
      bundle = ../modules/bundles/desktop.nix;
      userModule = ../users/seeker;
    };
    DiagonAlley = {
      bundle = ../modules/bundles/desktop.nix;
      userModule = ../users/seeker;
    };
    devVM = {
      bundle = ../modules/bundles/development.nix;
      userModule = ../users/seeker/headless.nix;
    };
    nixos-wsl = {
      system = "x86_64-linux";
      bundle = ../modules/bundles/wsl.nix;
      extraModules = [ inputs.nixos-wsl.nixosModules.default ];
      userModule = ../users/seeker/wsl.nix;
    };
    "King'sCross" = {
      hostDir = ../hosts/KingsCross;
      bundle = ../modules/bundles/server.nix;
    };
    burrow = {
      bundle = ../modules/bundles/gateway.nix;
      userModule = ../users/seeker/burrow.nix;
    };
  };

  mkHost =
    name:
    {
      hostDir ? ../hosts/${name},
      system ? (import (hostDir + "/meta.nix")).system,
      bundle,
      extraModules ? [ ],
      userModule ? null,
    }:
    mkNixos {
      inherit system;
      baseModules = [
        ./common/nixpkgs-settings.nix
        bundle
      ]
      ++ extraModules;
      modules = [ hostDir ] ++ lib.optional (userModule != null) userModule;
    };

  devVMConfiguration = mkHost "devVM" hosts.devVM;
  devVMQemu = devVMConfiguration.config.system.build.vmWithBootLoader;
  devVMMeta = import ../hosts/devVM/meta.nix;
in
{
  flake.nixosConfigurations = lib.mapAttrs mkHost hosts;

  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      runDevVmQemu = pkgs.writeShellScript "run-dev-vm-qemu" ''
        state_root="''${XDG_STATE_HOME:-$HOME/.local/state}"
        state_dir="$state_root/dev-vm-qemu"
        legacy_state_dir="$state_root/dev-container-qemu"
        if [ ! -e "$state_dir/devVM.qcow2" ] && [ -e "$legacy_state_dir/devVM.qcow2" ]; then
          state_dir="$legacy_state_dir"
        fi
        ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
        export NIX_DISK_IMAGE="''${NIX_DISK_IMAGE:-$state_dir/devVM.qcow2}"
        exec ${devVMQemu}/bin/run-${devVMMeta.hostName}-vm "$@"
      '';
    in
    {
      packages = lib.optionalAttrs (system == devVMMeta.system) {
        inherit devVMQemu;
      };
      apps = lib.optionalAttrs (system == devVMMeta.system) {
        devVMQemu = {
          type = "app";
          program = "${runDevVmQemu}";
          meta.description = "Build and start the development NixOS VM with QEMU";
        };
      };
    };
}
