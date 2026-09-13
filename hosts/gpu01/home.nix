# Standalone home-manager target for the gpu01 cluster login node (see
# outputs/home-configurations.nix); this is not a NixOS host module.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sshKeys = import ../../users/seeker/ssh-public-keys.nix;
  authorizedKeysFile = pkgs.writeText "gpu01-authorized-keys" (
    builtins.concatStringsSep "\n" sshKeys.authorizedKeys + "\n"
  );
in
{
  imports = [ ../../users/seeker/ssh-client-secrets.nix ];

  home = {
    username = "seeker4721";
    homeDirectory = "/home/${config.home.username}";
  };

  machine.programs.nixvim.development.enable = true;

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # OpenSSH StrictModes rejects symlinks into this cluster's shared Nix store,
  # whose paths are not owned by seeker4721 or root. Install a user-owned file.
  home.activation.installAuthorizedKeys = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 0700 "$HOME/.ssh"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 \
      ${authorizedKeysFile} "$HOME/.ssh/.authorized_keys.home-manager"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv -fT \
      "$HOME/.ssh/.authorized_keys.home-manager" "$HOME/.ssh/authorized_keys"
  '';

  # The cluster owns /etc/passwd; hand interactive login shells to Fish here.
  programs.bash.profileExtra = ''
    case $- in
      *i*)
        if [ -t 0 ] \
          && [ -t 1 ] \
          && [ -n "''${SSH_TTY-}" ] \
          && [ -z "''${SSH_ORIGINAL_COMMAND-}" ] \
          && [ "''${TERM_PROGRAM-}" != "vscode" ] \
          && [ -z "''${VSCODE_IPC_HOOK_CLI-}" ]; then
          exec ${config.programs.fish.package}/bin/fish
        fi
        ;;
    esac
  '';
}
