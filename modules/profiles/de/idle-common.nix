# Shared idle/lock definitions rendered by each compositor into its own schema
# (services.hypridle for Hyprland, services.swayidle for niri).
{ lib, pkgs }:
let
  swaylockPackage = pkgs.swaylock-effects;
in
{
  timeouts = {
    notify = 240;
    lock = 300;
    suspend = 600;
  };

  onBattery = "${pkgs.acpi}/bin/acpi -a | ${pkgs.gnugrep}/bin/grep -q off-line";

  zzzNotify = "${pkgs.libnotify}/bin/notify-send Zzz";
  lockSession = "${pkgs.systemd}/bin/loginctl lock-session";
  suspendThenHibernate = "${pkgs.systemd}/bin/systemctl suspend-then-hibernate";

  inherit swaylockPackage;
  pidof = "${pkgs.procps}/bin/pidof";
  swaylockCommand = "${pkgs.procps}/bin/pidof swaylock || ${lib.getExe swaylockPackage} -f";
}
