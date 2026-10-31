{
  imports = [
    ./netbird.nix
    ./secrets.nix
    ./taskchampion.nix
    ./personal-storage
    ./uni-next.nix
    ../../modules/profiles/system/core/vps.nix
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
