# Exercise dependency and feature toggles without building system closures.
{
  inputs,
  self,
  pkgs,
}:
let
  lib = inputs.nixpkgs.lib;
  keyringFor =
    zed: override:
    (lib.nixosSystem {
      modules = [
        inputs.home-manager.nixosModules.home-manager
        ../modules/profiles/programs/zed.nix
        {
          nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
          home-manager.users.test = {
            home.stateVersion = "24.05";
            programs.zed-editor.enable = zed;
          };
        }
        (lib.optionalAttrs (override != null) {
          services.gnome.gnome-keyring.enable = override;
        })
      ];
    }).config.services.gnome.gnome-keyring.enable;

  desktop = self.nixosConfigurations.miLaptop;
  withoutPanel =
    (desktop.extendModules {
      modules = [ { machine.de.quickshell.enable = false; } ];
    }).config.home-manager.users.seeker;
  withoutTasks =
    (desktop.extendModules {
      modules = [ { home-manager.users.seeker.programs.taskwarrior.enable = false; } ];
    }).config.home-manager.users.seeker;
in
assert lib.assertMsg (keyringFor true null) "Zed must request keyring by default";
assert lib.assertMsg (!(keyringFor false null)) "Disabled Zed must not request keyring";
assert lib.assertMsg (
  !(keyringFor true false)
) "Explicit keyring policy must override Zed's default";
assert lib.assertMsg (keyringFor false true) "Other consumers must be able to enable keyring";
assert lib.assertMsg withoutPanel.programs.taskwarrior.enable
  "Taskwarrior must remain independent of Quickshell";
assert lib.assertMsg (
  !withoutTasks.programs.taskwarrior.enable
) "Quickshell must not enable Taskwarrior";
assert lib.assertMsg (
  !(withoutTasks.sops.secrets ? taskwarrior_client_id)
) "Disabled Taskwarrior must not deploy sync credentials";
assert lib.assertMsg (
  !(withoutTasks ? machine.de)
) "Home Manager must not declare a second desktop option tree";
pkgs.writeText "module-policies" "Module dependency checks passed.\n"
