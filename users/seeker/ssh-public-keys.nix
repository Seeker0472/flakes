let
  files = {
    admin = ./ssh/admin.secrets.json;
    external = ./ssh/external.secrets.json;
    DiagonAlley = ./ssh/DiagonAlley.secrets.json;
    miLaptop = ./ssh/miLaptop.secrets.json;
    devVM = ./ssh/devVM.secrets.json;
    nixos-wsl = ./ssh/nixos-wsl.secrets.json;
    Hippogriff = ./ssh/Hippogriff.secrets.json;
    github = ./ssh/github.secrets.json;
  };
  readPublicKey = file: (builtins.fromJSON (builtins.readFile file)).public_key_unencrypted;
  adminKey = readPublicKey files.admin;
  clientKeys = {
    DiagonAlley = readPublicKey files.DiagonAlley;
    miLaptop = readPublicKey files.miLaptop;
    devVM = readPublicKey files.devVM;
    nixos-wsl = readPublicKey files.nixos-wsl;
    Hippogriff = readPublicKey files.Hippogriff;
  };
  githubKey = readPublicKey files.github;
in
{
  inherit files;

  admin = adminKey;
  external = readPublicKey files.external;

  clients = clientKeys;

  github = githubKey;

  authorizedKeys = [ adminKey ] ++ builtins.attrValues clientKeys;
}
