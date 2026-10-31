{ inputs, self, ... }:
let
  lib = inputs.nixpkgs.lib;

  mkHost =
    module:
    lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./common/nixpkgs-settings.nix
        module
      ];
    };
  devVM = self.nixosConfigurations.devVM.config;
  devVMQemu = devVM.system.build.vmWithBootLoader;
in
{
  flake.nixosConfigurations = {
    miLaptop = mkHost ../hosts/miLaptop;
    DiagonAlley = mkHost ../hosts/DiagonAlley;
    devVM = mkHost ../hosts/devVM;
    nixos-wsl = mkHost ../hosts/nixos-wsl;
    "King'sCross" = mkHost ../hosts/KingsCross;
    Willow = mkHost ../hosts/Willow;
    burrow = mkHost ../hosts/burrow;
    Hippogriff = mkHost ../hosts/Hippogriff;
    HippogriffFast = mkHost ../hosts/Hippogriff/fast.nix;
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
        exec ${devVMQemu}/bin/run-${devVM.networking.hostName}-vm "$@"
      '';
    in
    {
      packages = lib.optionalAttrs (system == devVM.nixpkgs.hostPlatform.system) {
        inherit devVMQemu;
      };
      apps = lib.optionalAttrs (system == devVM.nixpkgs.hostPlatform.system) {
        devVMQemu = {
          type = "app";
          program = "${runDevVmQemu}";
          meta.description = "Build and start the development NixOS VM with QEMU";
        };
      };
    };
}
