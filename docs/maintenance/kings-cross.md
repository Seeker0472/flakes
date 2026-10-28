# King'sCross Maintenance

King'sCross configures `vps.seekerer.com`. Routine updates use deploy-rs, not
`nixos-anywhere`.

## Deploy

Deploy-rs is the default; node settings are in `flake.deploy.nodes.kingsCross`:

```bash
nix run .#deploy-rs -- .#kingsCross
```

It builds locally, copies the closure to `root@vps.seekerer.com` over ssh-ng
(key `~/.ssh/id_admin`), updates `/nix/var/nix/profiles/system`, and runs
`switch-to-configuration switch` (which installs the bootloader). magicRollback
reverts the profile if SSH stops responding during activation. Keep the
provider console/VNC available for networking, SSH, kernel, or bootloader
changes: rollback does not cover every failure mode. `switch` normally does
not require a reboot.

Useful switches:

```bash
nix run .#deploy-rs -- .#kingsCross --dry-activate  # run activation without setting the profile
nix run .#deploy-rs -- .#kingsCross --skip-checks   # skip the pre-deploy flake checks
```

`--test` still sets the profile; it is not equivalent to
`nixos-rebuild test`.

## Fallback without deploy-rs

If deploy-rs is unavailable, use this `nixos-rebuild` fallback:

```bash
cd /home/seeker/nixos-config

export NIX_SSHOPTS="-4 -i /home/seeker/.ssh/id_admin -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=30 -o ConnectionAttempts=3 -o ServerAliveInterval=10 -o ServerAliveCountMax=6"
FLAKE_REF="path:$PWD#King'sCross"

# Check the flake and build without changing the VPS.
nix flake check --no-build --no-write-lock-file "$FLAKE_REF"
nix run nixpkgs#nixos-rebuild -- dry-build \
  --no-write-lock-file \
  --flake "$FLAKE_REF"

# Activate temporarily. A reboot falls back to the previous switch.
nix run nixpkgs#nixos-rebuild -- test \
  --no-write-lock-file \
  --flake "$FLAKE_REF" \
  --target-host root@vps.seekerer.com \
  --use-substitutes

# Make the tested configuration the boot default.
nix run nixpkgs#nixos-rebuild -- switch \
  --no-write-lock-file \
  --flake "$FLAKE_REF" \
  --target-host root@vps.seekerer.com \
  --use-substitutes
```

## Ports

- The reserved band `28400-28499` is open for TCP and UDP in the host
  firewall. Put temporary services there instead of editing firewall rules.
- Persistent services declare their own ports in their modules (for example
  `hosts/KingsCross/netbird.nix`). Anything outside the band needs a firewall
  entry in the owning module.
- If the provider keeps a security group or firewall in front of the VPS, open
  the same ports there too; the NixOS firewall only filters packets that reach
  the host.
