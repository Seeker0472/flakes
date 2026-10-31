{ inputs, ... }:
{
  imports = [
    ./development.nix
    ../profiles/de/desktop.nix
    # Providers for the shared storage and persistence profiles below.
    inputs.impermanence.nixosModule
    inputs.disko.nixosModules.disko
    ../profiles/impermanence/btrfs.nix
    ../profiles/impermanence/config.nix
    ../profiles/de/hyprland/default.nix
    ../profiles/de/niri/default.nix
    ../profiles/de/common.nix
    ../profiles/programs/zed.nix
    ../profiles/programs/kde-connect.nix
    ../profiles/programs/mihomo/mihomo.nix
    ../profiles/programs/netbird.nix
    ../profiles/programs/steam.nix
    ../profiles/programs/tailscale.nix
    ../profiles/programs/thunar.nix
    ../profiles/programs/winapps.nix
    ../profiles/secrets/gpg.nix
    ../profiles/system/core/virtualization.nix
    # hardware/intel.nix and hardware/laptop.nix are imported unconditionally
    # by base-system.nix and gate themselves on machine.cpu / machine.type.
  ];
}
