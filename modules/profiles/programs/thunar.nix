{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.programs.thunar.enable {
    programs.thunar = {
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    programs.xfconf.enable = true;

    services.gvfs.enable = true;
    services.tumbler.enable = true; # 缩略图服务
  };
}
