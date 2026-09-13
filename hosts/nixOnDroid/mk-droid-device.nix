# Shared per-device module factory for nix-on-droid devices.
{ deviceName }:
{ ... }:
{
  environment.motd = "nix-on-droid: ${deviceName}";
  environment.sessionVariables.NIX_ON_DROID_DEVICE = deviceName;
}
