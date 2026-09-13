# Shared Disko GPT fragment for the EFI System Partition (mounted at /boot).
{
  size = "512M";
  type = "EF00";
  content = {
    type = "filesystem";
    format = "vfat";
    mountpoint = "/boot";
    mountOptions = [ "umask=0077" ];
  };
}
