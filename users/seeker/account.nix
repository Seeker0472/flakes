# Shared NixOS account identity; Home Manager profiles choose their own apps.
let
  sshKeys = import ./ssh-public-keys.nix;
in
{
  users.users.seeker = {
    isNormalUser = true;
    uid = 1000;
    description = "seeker";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "audio"
      "video"
      "input"
      "disk"
      "dialout"
      "i2c"
    ];
    hashedPassword = "$6$3nvVWJDicXst2Wtt$EdriZ4ylx/y7yEVEINT3k3JdrjF1MQG6ysITGmTR5pDiiceX2t8RjJiDutZyez2TQ/WeX1BB34/hMwF.s1m4L.";
    openssh.authorizedKeys.keys = sshKeys.authorizedKeys;
  };
}
