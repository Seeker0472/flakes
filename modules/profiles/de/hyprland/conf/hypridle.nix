{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  hyprlandEnabled = (import ../../enabled.nix lib osConfig);
  idle = import ../../idle-common.nix { inherit lib pkgs; };
in
{
  config = lib.mkIf hyprlandEnabled {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "${idle.pidof} hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
          before_sleep_cmd = idle.lockSession;
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
        };

        listener = [
          {
            timeout = idle.timeouts.notify;
            on-timeout = "${idle.onBattery} && ${idle.zzzNotify}";
          }
          {
            timeout = idle.timeouts.lock;
            on-timeout = "${idle.onBattery} && ${idle.lockSession}";
          }
          {
            timeout = idle.timeouts.suspend;
            on-timeout = "${idle.onBattery} && ${idle.suspendThenHibernate}";
          }
        ];
      };
    };
  };
}
