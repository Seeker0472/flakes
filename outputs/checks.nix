{ inputs, self, ... }:
let
  lib = inputs.nixpkgs.lib;
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      # Force configuration evaluation, then discard string context so running
      # the tests never builds every host's system or Home Manager closure.
      configurations = builtins.unsafeDiscardStringContext (
        builtins.toJSON {
          nixos = lib.mapAttrs (_: host: host.config.system.build.toplevel.drvPath) (
            lib.filterAttrs (
              _: host: host.config.nixpkgs.hostPlatform.system == system
            ) self.nixosConfigurations
          );
          home = lib.mapAttrs (_: home: home.activationPackage.drvPath) (
            lib.filterAttrs (_: home: home.pkgs.stdenv.hostPlatform.system == system) self.homeConfigurations
          );
          # Droid's full activation references an upstream bootstrap store path
          # that may not exist on the checking machine. Validate its assertions
          # and full Home Manager derivation without fetching that bootstrap.
          droid =
            lib.mapAttrs
              (
                _: droid:
                assert lib.assertMsg (lib.all (
                  a: a.assertion
                ) droid.config.assertions) "Nix-on-Droid configuration assertions failed";
                droid.config.home-manager.config.home.activationPackage.drvPath
              )
              (
                lib.filterAttrs (
                  _: droid: droid.pkgs.stdenv.hostPlatform.system == system
                ) self.nixOnDroidConfigurations
              );
        }
      );
    in
    {
      checks = {
        module-policies = import ../checks/module-policies.nix { inherit inputs self pkgs; };
        configuration-evaluation = pkgs.writeText "configuration-evaluation.json" configurations;

        fancontrol =
          pkgs.runCommand "fancontrol-tests"
            {
              nativeBuildInputs = [ pkgs.python3 ];
              FANCONTROL_UNDER_TEST = lib.getExe' pkgs.lm_sensors "fancontrol";
            }
            ''
              python3 -B ${../hosts/DiagonAlley/fancontrol}/test_controller.py
              touch "$out"
            '';

        netbird-uni-next =
          pkgs.runCommand "netbird-uni-next-tests"
            {
              nativeBuildInputs = [ pkgs.python3 ];
            }
            ''
              cp ${../hosts/KingsCross/test_netbird_uni_next_sync.py} test_netbird_uni_next_sync.py
              cp ${../hosts/KingsCross/netbird-uni-next-sync.py} netbird-uni-next-sync.py
              python3 -B test_netbird_uni_next_sync.py
              touch "$out"
            '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        quickshell =
          pkgs.runCommand "quickshell-lint"
            {
              nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
            }
            ''
              export HOME="$TMPDIR/home"
              export XDG_CACHE_HOME="$TMPDIR/cache"
              mkdir -p "$HOME" "$XDG_CACHE_HOME"
              qmllint \
                --import disable \
                --unqualified disable \
                --unused-imports disable \
                --uncreatable-type disable \
                -I ${pkgs.quickshell}/lib/qt-6/qml \
                -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
                ${../modules/profiles/de/quickshell/shell}/*.qml
              touch "$out"
            '';
      };
    };
}
