{ ... }:
{
  # Shared tablet integration; each host selects features through native
  # options and the remaining profiles that express repository-specific policy.
  imports = [
    ./development.nix
    ../profiles/programs/zed.nix
    ../profiles/programs/kde-connect.nix
    ../profiles/programs/mihomo/mihomo.nix
    ../profiles/programs/netbird.nix
    ../profiles/secrets/gpg.nix
    ../profiles/system/core/virtualization.nix
  ];
}
