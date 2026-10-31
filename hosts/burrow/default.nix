{
  imports = [
    ./disk.nix
    ./hardware-configuration.nix
    ./networking.nix
    {
      programs.nixvim = {
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
      };
    }
  ];
}
