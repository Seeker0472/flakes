{
  metaFile,
  extraModules ? [ ],
}:
let
  host = import metaFile;
in
{
  imports = extraModules;

  networking.hostName = host.hostName;
  system.stateVersion = host.stateVersion;
  machine =
    host.machine
    // (
      if host ? disk then
        {
          disko = host.disk // {
            enable = true;
          };
        }
      else
        { }
    );
}
