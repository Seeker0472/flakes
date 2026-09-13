{ config, lib, ... }:
{
  options.machine.secrets = {
    deploy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable secret deployment via sops-nix";
    };
    ageKeyPath = lib.mkOption {
      type = lib.types.str;
      default =
        let
          prefix = if config.machine.impermanence.enable then "/persist/home" else "/home";
        in
        "${prefix}/${config.machine.mainUser}/.config/sops/age/keys.txt";
      description = "Path to the age key file";
    };
  };
  config = lib.mkIf config.machine.secrets.deploy {
    sops.age.keyFile = config.machine.secrets.ageKeyPath;
  };
}
