{
  lib,
  osConfig,
  ...
}:
{
  config = lib.mkIf osConfig.machine.programs.kdeconnect.enable {
    services.kdeconnect.enable = true;
  };
}
