# King'sCross Maintenance

King'sCross is the NixOS configuration for `vps.seekerer.com`. Build and
activate it from the flake repository; routine updates do not use
`nixos-anywhere`.

## Deploy

Deploy with deploy-rs - the default path for routine updates; the SSH options
and the profile live in `flake.deploy.nodes.kingsCross`:

```bash
nix run .#deploy-rs -- .#kingsCross
```

It builds locally, pushes the closure to `root@vps.seekerer.com` over the
ssh-ng store (key `~/.ssh/id_admin`), sets `/nix/var/nix/profiles/system` and
activates with `switch-to-configuration switch`; that activation installs the
bootloader as well. deploy-rs' magicRollback activates the new generation
under a temporary profile first and reverts the profile when the host stops
answering SSH, so a deploy that cuts the connection rolls back on its own.

Keep the provider console/VNC available while deploying changes to
networking, SSH, the kernel or the boot loader: rollback covers a lost
connection, not every failure mode. `switch` normally does not require a
reboot.

Useful switches:

```bash
nix run .#deploy-rs -- .#kingsCross --dry-activate  # run activation without setting the profile
nix run .#deploy-rs -- .#kingsCross --skip-checks   # skip the pre-deploy flake checks
```

(`--test` exists, but deploy-rs still sets the profile in that mode; it is not
the same as `nixos-rebuild test`.)

## Fallback without deploy-rs

The previous `nixos-rebuild` flow still works and is the way out if deploy-rs
is unavailable:

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
