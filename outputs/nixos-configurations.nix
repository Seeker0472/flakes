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
      # The release profile must also evaluate on the aarch64 tablet itself;
      # the fast profile patches on its x86_64 build host.
      patchPkgs = inputs.nixpkgs.legacyPackages.${if fast then "x86_64-linux" else "aarch64-linux"};
      patchedLiuqinSource = patchPkgs.applyPatches {
        name = "liuqin-nixos-nixos-26.11-initrd";
        src = liuqin.outPath;
        patches = [
          (builtins.toFile "liuqin-initrd-enable.patch" ''
            diff --git a/modules/liuqin/default.nix b/modules/liuqin/default.nix
            --- a/modules/liuqin/default.nix
            +++ b/modules/liuqin/default.nix
            @@ -240,7 +240,6 @@
                   };

                   # systemd-based stage 1 is the only supported initrd here.
            -      boot.initrd.systemd.enable = lib.mkDefault true;
                   # The device kernel has UFS, SCSI, ext4, IOMMU and the USB/input path
                   # built in. NixOS' generic initrd module list contains PC-only entries
                   # such as ata_piix; asking module-rebuild to resolve that list makes a
            diff --git a/modules/liuqin/initrd-guard.nix b/modules/liuqin/initrd-guard.nix
            --- a/modules/liuqin/initrd-guard.nix
            +++ b/modules/liuqin/initrd-guard.nix
            @@ -103,5 +103,4 @@
                 boot.initrd.systemd = {
            -      enable = true;
                   # The initrd systemd image does not infer these paths from the shell
                   # text in ExecStart. The guard package and every command it puts on its
                   # own PATH (its runtimeInputs) must be copied into the image explicitly.
          '')
        ];
      };
      # NixOS 26.11 removed this no-op option; patch only those obsolete
      # assignments while retaining the port's initrd guard and other modules.
      liuqinModule = {
        imports = [ (patchedLiuqinSource + "/modules/liuqin") ];
      };
      inject = import (liuqin.outPath + "/overlay-inject.nix") {
        pkgsArm = liuqin.lib.pkgsArm;
      };
      # buildLinux now presents .config as a read-only store symlink here;
      # Liuqin's postConfigure appends fragments, so materialize a writable copy.
      kernelConfigOverlay =
        _final: prev:
        let
          writableKernelConfig =
            kernel:
            kernel.overrideAttrs (old: {
              postConfigure = ''
                : "''${buildRoot:=build}"
                cp "$buildRoot/.config" "$buildRoot/.config.tmp"
                chmod u+w "$buildRoot/.config.tmp"
                mv "$buildRoot/.config.tmp" "$buildRoot/.config"
              ''
              + (old.postConfigure or "");
            });
        in
        {
          liuqinKernel = writableKernelConfig prev.liuqinKernel;
          liuqinInstallerKernel = writableKernelConfig prev.liuqinInstallerKernel;
        };
    in
    lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.overlays = [
            liuqin.overlays.default
          ]
          ++ lib.optional fast inject
          ++ [ kernelConfigOverlay ];
          nixpkgs.config.allowUnfreePredicate = liuqin.lib.allowLiuqinUnfree;
        }
        liuqinModule
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
