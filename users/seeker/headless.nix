{ ... }:
{
  imports = [
    ./account.nix
  ];

  home-manager = {
    users.seeker = {
      imports = [
        ./hm-base.nix
        ./home.nix
        ./ssh-secrets.nix
      ];
    };
  };
}
