# AliCloud credentials shared by the AliDNS ACME certificates of both
# netbird.nix and taskchampion.nix. Declared here so no service file depends
# on another service file's sops declarations.
{ ... }:
{
  sops.secrets = {
    alicloud_access_key.sopsFile = ./netbird.secrets.yaml;
    alicloud_secret_key.sopsFile = ./netbird.secrets.yaml;
  };
}
