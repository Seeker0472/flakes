{ ... }:
{
  # Tablet-class hosts: the development base (CLI tooling, nixvim), the GNOME
  # integration the device's session expects, and the optional program
  # profiles a dev machine turns on (KDE Connect, mihomo, NetBird, GnuPG,
  # containers). Each profile is gated by its machine.programs.* /
  # machine.virtualization.* switch, so importing it stays inert until the
  # host's meta.nix enables it. The desktop-only heavy profiles (Steam,
  # WinApps, the DE stacks, the media editing set) stay out.
  imports = [
    ./development.nix
    ../profiles/programs/gnome-keyring.nix
    ../profiles/programs/kde-connect.nix
    ../profiles/programs/mihomo/mihomo.nix
    ../profiles/programs/netbird.nix
    ../profiles/secrets/gpg.nix
    ../profiles/system/core/virtualization.nix
  ];
}
