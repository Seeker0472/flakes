{ lib, pkgs, ... }:
{
  nix = {
    settings = {
      substituters = [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
      ];
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
  # Select internationalisation properties.
  i18n.defaultLocale = lib.mkDefault "en_HK.UTF-8";

  #Make Windows Happy
  # A better way is to let windows use UTC time
  # time.hardwareClockInLocalTime = true;

  time.timeZone = lib.mkDefault "Asia/Hong_Kong";

  environment.variables.EDITOR = lib.mkOverride 950 "vim";

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    python3
    fish
    rclone
  ];

}
