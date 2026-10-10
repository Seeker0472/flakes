# King'sCross Maintenance

King'sCross is the NixOS configuration for `vps.seekerer.com`. Build and
activate it from the flake repository; routine updates do not use
`nixos-anywhere`.

## Test and Deploy

Run these commands from `/home/seeker/nixos-config`:

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

# Confirm the normal account and system are healthy.
ssh seeker@vps.seekerer.com \
  'sudo -n true && systemctl is-system-running --wait'

# Make the tested configuration the boot default.
nix run nixpkgs#nixos-rebuild -- switch \
  --no-write-lock-file \
  --flake "$FLAKE_REF" \
  --target-host root@vps.seekerer.com \
  --use-substitutes
```

`switch` normally does not require a reboot. Keep the VNC/console available
while testing changes to networking, SSH, the kernel, or the boot loader.

After the configuration files are committed and tracked, `FLAKE_REF` can be
shortened to `".#King'sCross"`.

## Ports

- The reserved band `28400-28499` is open for TCP and UDP in the host
  firewall. Put temporary services there instead of editing firewall rules.
- Persistent services declare their own ports in their modules (for example
  `hosts/KingsCross/netbird.nix`). Anything outside the band needs a firewall
  entry in the owning module.
- If the provider keeps a security group or firewall in front of the VPS, open
  the same ports there too; the NixOS firewall only filters packets that reach
  the host.
