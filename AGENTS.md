# Repository Instructions

## Deployment

`miLaptop`, `King'sCross` and `Hippogriff` are deployed with deploy-rs from
this flake:

```bash
nix run .#deploy-rs -- .#miLaptop
nix run .#deploy-rs -- .#kingsCross
nix run .#deploy-rs -- .#hippogriff
```

deploy-rs builds locally, pushes the closure over the ssh-ng store and
activates with `switch-to-configuration switch`; its magicRollback watches the
connection and rolls the profile back when a deploy cuts it. `miLaptop` and
`Hippogriff` prompt for the account's sudo password (`interactiveSudo`).

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
