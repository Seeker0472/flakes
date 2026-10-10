{
  inputs,
  self,
  ...
}:
let
  lib = inputs.nixpkgs.lib;

  # deploy-rs' lib functions bind the deploy-rs *package* into the activation
  # wrapper they build. Use the official overlay for the lib, but take the
  # package from plain nixpkgs: it is in the binary cache for both target
  # systems, while the flake's own build is not.
  deployPkgs =
    system:
    let
      plain = inputs.nixpkgs.legacyPackages.${system};
    in
    import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.deploy-rs.overlays.default
        (final: prev: {
          deploy-rs = {
            inherit (plain) deploy-rs;
            lib = prev.deploy-rs.lib;
          };
        })
      ];
    };

  mkNode =
    system:
    {
      hostName,
      hostname,
      sshUser,
      sshOpts,
      interactiveSudo ? false,
    }:
    {
      inherit
        hostname
        sshUser
        sshOpts
        interactiveSudo
        ;
      profiles.system = {
        user = "root";
        path = (deployPkgs system).deploy-rs.lib.activate.nixos self.nixosConfigurations.${hostName};
      };
    };

  key = "/home/seeker/.ssh/id_admin";
in
{
  flake.deploy.nodes = {
    miLaptop = mkNode "x86_64-linux" {
      hostName = "miLaptop";
      hostname = "miLaptop";
      sshUser = "seeker";
      sshOpts = [
        "-i"
        key
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "ConnectTimeout=10"
      ];
      interactiveSudo = true;
    };

    kingsCross = mkNode "x86_64-linux" {
      hostName = "King'sCross";
      hostname = "vps.seekerer.com";
      sshUser = "root";
      # Same options the maintenance doc's nixos-rebuild fallback exports.
      sshOpts = [
        "-4"
        "-i"
        key
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "BatchMode=yes"
        "-o"
        "ConnectTimeout=30"
        "-o"
        "ServerAliveInterval=10"
        "-o"
        "ServerAliveCountMax=6"
      ];
    };

    hippogriff = mkNode "aarch64-linux" {
      hostName = "Hippogriff";
      hostname = "192.168.11.132";
      sshUser = "seeker";
      sshOpts = [
        "-i"
        key
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "ConnectTimeout=10"
      ];
      interactiveSudo = true;
    };
  };

  perSystem =
    { system, ... }:
    let
      deployChecks = (deployPkgs system).deploy-rs.lib.deployChecks self.deploy;
    in
    {
      # Keep deploy-rs' `deploy-schema` check; drop `deploy-activate`, which
      # requires every node's activation package (all three system closures,
      # including the aarch64 Hippogriff one) to be built - and deploy-rs runs
      # the whole `nix flake check` before every deployment. Verify a single
      # node's wrapper explicitly when wanted:
      #   nix build .#deploy.nodes.<name>.profiles.system.path
      checks = lib.filterAttrs (name: _: name == "deploy-schema") deployChecks;

      apps.deploy-rs = {
        type = "app";
        program = "${(deployPkgs system).deploy-rs.deploy-rs}/bin/deploy";
        meta.description = "deploy-rs with this repository's deployment definitions";
      };
    };
}
