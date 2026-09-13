{
  lib,
  osConfig,
  ...
}:
let
  fcitx5Enable =
    (lib.attrByPath [
      "i18n"
      "inputMethod"
      "enable"
    ] false osConfig)
    &&
      (lib.attrByPath [
        "i18n"
        "inputMethod"
        "type"
      ] "" osConfig) == "fcitx5";
in
{
  config = lib.mkIf fcitx5Enable {
    home.file = {
      ".local/share/fcitx5/themes/Nord-Dark".source = ./fcitx5-nord/Nord-Dark;
      ".local/share/fcitx5/themes/Nord-Light".source = ./fcitx5-nord/Nord-Light;
      ".config/fcitx5/conf/classicui.conf".source = ./conf/classicui.conf;
    };
  };
}
