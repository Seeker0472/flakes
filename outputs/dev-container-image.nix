{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;

  mkDevContainerImage =
    pkgs:
    let
      user = "seeker";
      uid = 1000;
      gid = 1000;
      uidStr = toString uid;
      gidStr = toString gid;
      homeDirectory = "/home/${user}";

      # Single source for the nix settings baked into the image: consumed both
      # by the Home Manager activation and by the entrypoint's NIX_CONFIG.
      nixSettings = {
        build-users-group = "";
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        sandbox = false;
      };
      nixConfigText = lib.generators.toKeyValue {
        mkKeyValue =
          key: value:
          "${key} = ${
            if builtins.isList value then lib.concatStringsSep " " value else builtins.toString value
          }";
      } nixSettings;

      homeConfiguration = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ../users/seeker/home.nix
          (
            { lib, ... }:
            {
              home = {
                inherit uid homeDirectory;
                activationGenerateGcRoot = false;
                packages = with pkgs; [
                  coreutils
                  curl
                  findutils
                  gnugrep
                  gzip
                  neovim
                  nix
                  python3
                  rclone
                  vim
                  wget
                ];
                username = user;
              };
              nix = {
                package = pkgs.nix;
                settings = nixSettings;
              };
              programs.ai.enable = lib.mkForce false;
              systemd.user.enable = false;
            }
          )
        ];
      };

      activationPackage = homeConfiguration.activationPackage;
      homePath = "${activationPackage}/home-path";
      entrypoint = pkgs.writeShellScriptBin "dev-container-entrypoint" ''
        set -eu

        export HOME=${homeDirectory}
        export LOGNAME=${user}
        export NIX_CONFIG='${nixConfigText}'
        export USER=${user}

        mkdir -p "$HOME/.local/state/nix/profiles"
        ${activationPackage}/activate --driver-version 1 >&2

        if [ "$#" -eq 0 ]; then
          set -- ${pkgs.fish}/bin/fish
        fi

        exec "$@"
      '';
    in
    pkgs.dockerTools.buildLayeredImageWithNixDb {
      name = "nixos-devcontainer";
      tag = "latest";

      contents = [
        pkgs.dockerTools.binSh
        pkgs.dockerTools.caCertificates
        pkgs.dockerTools.usrBinEnv
        pkgs.nix
        entrypoint
      ];

      extraCommands = ''
        mkdir -p etc home/${user} tmp

        cat > etc/passwd <<'EOF'
        root:x:0:0:root:/root:/bin/sh
        ${user}:x:${uidStr}:${gidStr}:Developer:${homeDirectory}:${pkgs.fish}/bin/fish
        EOF

        cat > etc/group <<'EOF'
        root:x:0:
        ${user}:x:${gidStr}:
        EOF

        cat > etc/shadow <<'EOF'
        root:!x:::::::
        ${user}:!:::::::
        EOF

        cat > etc/gshadow <<'EOF'
        root:!::
        ${user}:!::
        EOF

        cat > etc/nsswitch.conf <<'EOF'
        passwd: files
        group: files
        hosts: files dns
        EOF
      '';

      fakeRootCommands = ''
        mkdir -p \
          ./nix/store \
          ./nix/var/nix/gcroots/per-user/${user} \
          ./nix/var/nix/profiles/per-user/${user} \
          ./etc/nix
        ln -sfn /nix/var/nix/profiles ./nix/var/nix/gcroots/profiles
        chown -R ${uidStr}:${gidStr} ./nix ./etc/nix
        chown -R ${uidStr}:${gidStr} ./home/${user}
        chmod 600 ./etc/shadow ./etc/gshadow
        chmod 1777 ./tmp
      '';

      config = {
        Entrypoint = [ "${entrypoint}/bin/dev-container-entrypoint" ];
        Env = [
          "EDITOR=vim"
          "HOME=${homeDirectory}"
          "LANG=C.UTF-8"
          "LOGNAME=${user}"
          "PATH=${homePath}/bin:${entrypoint}/bin:/usr/bin:/bin"
          "SHELL=${pkgs.fish}/bin/fish"
          "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
          "USER=${user}"
        ];
        User = "${uidStr}:${gidStr}";
        WorkingDir = homeDirectory;
      };

      passthru = {
        inherit activationPackage homeConfiguration;
      };
      meta.platforms = [ "x86_64-linux" ];
    };
in
{
  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        devContainerImage = mkDevContainerImage (import ./common/mk-pkgs.nix { inherit inputs system; });
      };
    };
}
