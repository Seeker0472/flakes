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
    Willow = {
      hostDir = ../hosts/Willow;
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

  # Two Xiaomi Pad 6 Pro variants, because the device packages decide both
  # the build cost and whether the tablet can rebuild its own boot chain.
  #
  # HippogriffFast injects the port's x86_64->aarch64 cross device packages
  # (kernel, U-Boot, firmware, sensors) and keeps the rest of the closure
  # native aarch64 from cache.nixos.org.  Only the per-machine derivations
  # (/etc, units, initrd) run through binfmt on the host.  Daily/test build.
  #
  # Hippogriff leaves every device package native aarch64.  The whole
  # closure builds on the tablet itself, or on the host through
  # binfmt/qemu-user; that is the release build when the tablet must be
  # able to rebuild or replace its boot chain locally.
  mkHippogriff =
    { fast }:
    let
      liuqin = inputs.liuqin;
      inject = import (liuqin.outPath + "/overlay-inject.nix") {
        pkgsArm = liuqin.lib.pkgsArm;
      };
    in
    lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        {
          # The port module installs its device overlay; injection must follow it.
          nixpkgs.overlays = lib.mkAfter (lib.optional fast inject);
          nixpkgs.config.allowUnfreePredicate = liuqin.lib.allowLiuqinUnfree;
        }
        liuqin.nixosModules.liuqin
        ./common/nixpkgs-settings.nix
        ../modules/bundles/tablet.nix
        ../users/seeker/hippogriff.nix
        ../hosts/Hippogriff
      ];
    };
in
{
  flake.nixosConfigurations = lib.mapAttrs mkHost hosts // {
    # The port's own mkLiuqinSystem builder cannot take specialArgs, and
    # this repository's modules expect the flake inputs as a module
    # argument, so the wiring above replicates it over lib.nixosSystem.
    Hippogriff = mkHippogriff { fast = false; };
    HippogriffFast = mkHippogriff { fast = true; };
  };

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
