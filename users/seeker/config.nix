{
  lib,
  ...
}:
{
  programs = {
    ai.enable = lib.mkDefault true;
    bash.enable = true;
    direnv.enable = true;
    fish.enable = true;
    tmux.enable = true;
    yazi.enable = true;
    zellij.enable = true;
  };
}
