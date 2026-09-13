{ config, lib, ... }:
let
  cfg = config.machine.programs.gnome-keyring;
in
{
  # Consumed by the zed home module (users/ scope) and by gnome-keyring's
  # default below.
  options.machine.programs.zed.enable = lib.mkEnableOption "Zed desktop integration";
  options.machine.programs.gnome-keyring.enable = lib.mkOption {
    type = lib.types.bool;
    # zed.enable keeps driving gnome-keyring by default so existing hosts
    # (which only set machine.programs.zed.enable) keep working.
    default = config.machine.programs.zed.enable;
    description = "Enable gnome-keyring (used by Zed and other desktop apps).";
  };

  config = lib.mkIf cfg.enable {
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
  };
}
