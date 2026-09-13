{ config, lib, ... }:
let
  defaultRootHashedPassword = "$6$Ew9uzvrMkL/nHax2$hovmxM9ttsZmDNkrh3Ah1S8FATYv5UDJp.5rwrWTFnZQBdifPpKD6inbv/QIA0ttXi07uaWOJtaFcGkuK/mPz.";
  enabledUsers = lib.filterAttrs (_: userCfg: userCfg.enable) config.machine.users;
  enabledUserNames = builtins.attrNames enabledUsers;
  usersMissingField =
    field: builtins.filter (name: enabledUsers.${name}.${field} == null) enabledUserNames;
  mkMissingFieldAssertion = field: messagePrefix: {
    assertion = usersMissingField field == [ ];
    message = messagePrefix + lib.concatStringsSep ", " (usersMissingField field);
  };
  enabledUids = map (name: enabledUsers.${name}.uid) enabledUserNames;
in
{
  # root 不在 machine.users 里（避免 root 被套进普通用户 submodule）
  options.machine.rootHashedPassword = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Hashed password for the root account.";
  };

  config = {
    assertions = [
      (mkMissingFieldAssertion "uid" "Enabled machine.users entries must define a unique uid when no built-in default exists: ")
      {
        assertion = builtins.length enabledUids == builtins.length (lib.unique enabledUids);
        message = "Enabled machine.users entries must use unique UIDs.";
      }
      (mkMissingFieldAssertion "hashedPassword" "Enabled machine.users entries must define a hashedPassword when no built-in default exists: ")
    ];
    users.mutableUsers = lib.mkDefault false;
    users.users = {
      root.hashedPassword =
        if config.machine.rootHashedPassword != null then
          config.machine.rootHashedPassword
        else
          defaultRootHashedPassword;
    }
    // lib.mapAttrs (_: userCfg: {
      isNormalUser = true;
      inherit (userCfg)
        description
        uid
        extraGroups
        hashedPassword
        ;
      openssh.authorizedKeys.keys = userCfg.authorizedKeys;
    }) enabledUsers;
  };
}
