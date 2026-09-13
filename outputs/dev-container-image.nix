{
  inputs,
  pkgs,
}:
let
  user = "seeker";
  uid = 1000;
  gid = 1000;
  homeDirectory = "/home/${user}";

  homeConfiguration = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      ../users/seeker/home.nix
      (
        { lib, ... }:
        {
          home = {
            inherit uid;
            inherit homeDirectory;
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
            settings = {
              build-users-group = "";
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              sandbox = false;
            };
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
    export NIX_CONFIG='build-users-group =
    experimental-features = nix-command flakes
    sandbox = false'
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
    ${user}:x:${toString uid}:${toString gid}:Developer:${homeDirectory}:${pkgs.fish}/bin/fish
    EOF

    cat > etc/group <<'EOF'
    root:x:0:
    ${user}:x:${toString gid}:
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
    chown -R ${toString uid}:${toString gid} ./nix ./etc/nix
    chown -R ${toString uid}:${toString gid} ./home/${user}
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
    User = "${toString uid}:${toString gid}";
    WorkingDir = homeDirectory;
  };

  passthru = {
    inherit activationPackage homeConfiguration;
  };
  meta.platforms = [ "x86_64-linux" ];
}
