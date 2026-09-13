{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.machine.de.niri.enable {
    programs.niri.enable = true;

    environment.systemPackages = [ pkgs.xwayland-satellite ];
  };
}
