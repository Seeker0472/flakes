{ lib, ... }:
{
  # Profile implementations live in explicit bundles under ./bundles.
  # Keeping this module options-only prevents every host from inheriting
  # desktop, development, and secret services by accident.
  options.machine = {
    type = lib.mkOption {
      type = lib.types.enum [
        "others"
        "laptop"
        "desktop"
        "server"
      ];
      default = "others";
      description = "The basic type of this machine";
    };
    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "seeker";
      # Personal default: fine for this single-user config; set machine.mainUser
      # explicitly on any host with a different primary user.
      description = "Main user of this machine";
    };
    cpu = lib.mkOption {
      type = lib.types.enum [
        "others"
        "intel"
        "amd"
      ];
      default = "others";
      description = "The CPU of this machine";
    };
    impermanence.enable = lib.mkEnableOption "impermanence";
  };
}
