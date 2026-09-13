{
  lib,
  config,
  ...
}:
let
  kdeConnectPorts = [
    {
      from = 1714;
      to = 1764;
    }
  ];
in
{
  options.machine.programs.kdeconnect.enable = lib.mkEnableOption "KDE Connect";
  config = lib.mkIf config.machine.programs.kdeconnect.enable {
    networking.firewall = {
      allowedTCPPortRanges = kdeConnectPorts;
      allowedUDPPortRanges = kdeConnectPorts;
    };
  };
}
