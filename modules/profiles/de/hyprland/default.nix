{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.machine.de.hyprland.enable {
    programs.hyprland = {
      enable = true;
    };
  };
}
