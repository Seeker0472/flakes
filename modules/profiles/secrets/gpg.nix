{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.gnupg.agent.enable {
    programs.gnupg.agent = {
      pinentryPackage = pkgs.pinentry-qt;
    };
  };
}
