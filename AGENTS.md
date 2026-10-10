# Repository Instructions

## Deployment

Routine deployments of `miLaptop`, `King'sCross` and `Hippogriff` use deploy-rs
from this flake - the repository's recommended default:

```bash
nix run .#deploy-rs -- .#miLaptop
nix run .#deploy-rs -- .#kingsCross
nix run .#deploy-rs -- .#hippogriff
```

Mode switches stay inside deploy-rs (`--dry-activate`, `--remote-build`,
`--hostname`, `--skip-checks`); a host this repository deploys over SSH gets a
`flake.deploy.nodes` entry (see `outputs/deploy.nix`).

deploy-rs builds locally (Hippogriff's device packages are native aarch64 and
build through binfmt here; `--remote-build` hands that build to the tablet
instead), then activates with `switch-to-configuration switch`; its
magicRollback watches the connection and rolls the profile back when a deploy
cuts it. `miLaptop` and `Hippogriff` prompt for the account's sudo password
(`interactiveSudo`).

`miLaptop` and `Hippogriff` have no stable address yet (DHCP, no local DNS
name): pass `--hostname <address>` when the lease moves, until the NetBird
overlay addresses land (TODO in `.todo.md`).

## King'sCross

The VPS configuration is `nixosConfigurations."King'sCross"` and targets
`root@vps.seekerer.com`. Follow [the maintenance workflow](docs/maintenance/kings-cross.md)
for changes. Keep the provider console reachable while deploying changes to
networking, SSH, the kernel, or boot settings: rollback covers a lost SSH
connection, not every failure mode. Do not use `nixos-anywhere` for routine
updates: it may run Disko and erase the VPS disk.
