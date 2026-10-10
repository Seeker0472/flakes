{ ... }:
{
  # Tablet-class hosts: the development base (CLI tooling, nixvim) plus the
  # desktop integration the device's GNOME session expects. Impermanence and
  # the desktop-only heavy profiles (Steam, WinApps, virtualization, media
  # editing packages) deliberately stay out of this bundle; enable the
  # machine.programs.* gates individually where wanted.
  imports = [
    ./development.nix
    ../profiles/programs/gnome-keyring.nix
  ];
}
