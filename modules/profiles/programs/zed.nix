# Zed needs a Secret Service implementation. Other consumers can request the
# same default; an explicit host choice for keyring still takes precedence.
{ config, lib, ... }:
{
  home-manager.sharedModules = [ ./home/zed.nix ];
  services.gnome.gnome-keyring.enable = lib.mkIf (lib.any (home: home.programs.zed-editor.enable) (
    lib.attrValues config.home-manager.users
  )) (lib.mkDefault true);
}
