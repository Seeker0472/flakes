{
  inputs,
  self,
  ...
}:
let
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
  # Addressing: King'sCross resolves by name, but miLaptop and Hippogriff are
  # on DHCP with no local DNS and no usable mDNS name, so their `hostname`
  # values below are placeholders for the current address. Override per
  # invocation meanwhile:
  #   nix run .#deploy-rs -- .#hippogriff --hostname 192.168.x.y
  # TODO(.todo.md): point both at the NetBird overlay addresses once the
  # tablet is enrolled and the deploying machines run netbird.
  flake.deploy.nodes = {
    miLaptop = mkNode "x86_64-linux" {
      hostName = "miLaptop";
      hostname = "miLaptop"; # override with --hostname <ip>
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
      hostname = "192.168.11.132"; # current lease; override with --hostname <ip>
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
    { pkgs, system, ... }:
    {
      # deploy-rs' own checks are deliberately not wired in:
      #  - `deploy-activate` requires every node's activation package to be
      #    built (all three system closures);
      #  - `deploy-schema` builds `builtins.toJSON deploy`, whose store-path
      #    strings carry their string context, so it pulls those same closures
      #    (bun/zig included) into a validation that only needs the JSON
      #    bytes.
      # deploy-rs runs the whole `nix flake check` before every deployment, so
      # both would make each deploy build every host. The schema check below
      # is the same validation with the context stripped; a single node's
      # activation wrapper is verified by building it, which the deploy does
      # anyway: nix build .#deploy.nodes.<name>.profiles.system.path
      checks.deploy-schema =
        pkgs.runCommand "deploy-rs-schema"
          {
            nativeBuildInputs = [ pkgs.check-jsonschema ];
          }
          ''
            check-jsonschema --schemafile ${inputs.deploy-rs}/interface.json \
              ${pkgs.writeText "deploy.json" (
                builtins.unsafeDiscardStringContext (builtins.toJSON self.deploy)
              )}
            touch $out
          '';

      apps.deploy-rs = {
        type = "app";
        program = "${(deployPkgs system).deploy-rs.deploy-rs}/bin/deploy";
        meta.description = "deploy-rs with this repository's deployment definitions";
      };
    };
}
