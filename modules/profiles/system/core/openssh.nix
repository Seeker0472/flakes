# SSH policy for interactive CLI hosts. VPS hosts own their root-login policy.
{ config, lib, ... }:
{
  config = lib.mkIf config.services.openssh.enable {
    services.openssh.settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = lib.mkDefault false;
    };
  };
}
