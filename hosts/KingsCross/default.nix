import ../lib/mk-host-module.nix {
  metaFile = ./meta.nix;
  extraModules = [
    ./netbird.nix
    ./secrets.nix
    ./taskchampion.nix
    ../lib/vps-base.nix
    (
      { inputs, ... }:
      {
        imports = [
          inputs.nixvim.nixosModules.nixvim
          ../../modules/profiles/programs/nixvim/default.nix
        ];

        programs.nixvim = {
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
        };

        services.qemuGuest.enable = true;
      }
    )
  ];
}
