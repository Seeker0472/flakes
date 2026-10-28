# Repository Instructions

## Deployment

Use deploy-rs for routine updates:

```bash
nix run .#deploy-rs -- .#miLaptop
nix run .#deploy-rs -- .#kingsCross
nix run .#deploy-rs -- .#willow
nix run .#deploy-rs -- .#hippogriff
```

Hippogriff also has the `hippogriff-fast` profile; choose one tablet profile per
update. Pass deploy-rs options such as `--remote-build`, `--dry-activate`, and
`--skip-checks` to the deploy command. Until `outputs/deploy.nix` uses verified
NetBird targets, miLaptop and both Hippogriff profiles require
`--hostname <verified-address>` from machines without local DNS or a matching
DHCP lease. miLaptop and Hippogriff prompt for the account sudo password.

## King'sCross

The configuration is `nixosConfigurations."King'sCross"`; routine updates use
deploy-rs, not `nixos-anywhere`. Keep the provider console available for
networking, SSH, kernel, or boot changes: magicRollback does not cover every
failure mode. See `docs/maintenance/kings-cross.md`.

## Willow

Use deploy-rs for routine updates. Its first `nixos-anywhere` installation must
use `--copy-host-keys` because the SOPS identity derives from the SSH host key.
Do not repartition during routine updates. See `docs/maintenance/willow.md`.
