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

## UniVPN route through NetBird

`hosts/KingsCross/uni-next.nix` runs `uni-next` with a dedicated TUN and a
separate `netbird-uni-next` routing peer. The NetBird client listens on UDP
28479, inside the reserved provider firewall band. The UniVPN password and
logout user ID are encrypted in `uni-next.secrets.yaml`; the VPN account name,
gateway, verified SPKI pin, reconnect policy, and exported address are Nix
settings. The `uni-next` client has already reached `10.19.20.1` through the
VPN with ICMP and TCP/22 in a temporary KingsCross test.

The desired NetBird API state lives in `uni-next.nix`: a named Network, one
`10.19.20.1/32` Resource, a single KingsCross routing peer with masquerade, and
a one-way policy from the existing `All` group to that resource. Every enrolled
NetBird peer can reach this one VPN host. Change `source_groups` if access
should be narrower. NetBird distributes the `/32` route to those peers, so no
second overlay address or address remapping is required.
The account's current address range is `100.4.0.0/16`; the sync task checks
that it still matches the Nix source CIDR before writing API state.

`netbird-uni-next-sync.service` reconciles those objects by name five minutes
after the timer starts and hourly thereafter. It can also be started manually
after activation. It creates a one-off setup key with the routing peer group, enrolls the
local NetBird client, then verifies that the group has exactly one peer. It
updates managed objects that drift and does not delete unrelated objects.
The service reads its management PAT from the mode `0400` sops-nix runtime
secret `/run/secrets/netbird-uni-next-api-token`. Its encrypted source is
`uni-next-api.secrets.yaml`; the token never enters `flake.nix` or the Nix
store. It belongs to the dedicated `uni-next-kingscross-sync` admin service
user and expires after one year. Rotate the PAT before expiry by updating that
SOPS file. The new secret restarts the sync service, and subsequent client
setup keys are generated through the API.

The flake pins a published `uni-next` revision containing the KingsCross TUN
fix and the named NetBird service option. Update that revision and its lock
entry together when upgrading the client. The host's existing iptables
firewall backend is retained; the module adds a
source-, destination-, and interface-limited TCP MSS clamp for forwarded
packets. Keep the provider console available during activation as described
above.

After activation, verify `systemctl status uni-next netbird-uni-next
netbird-uni-next-sync`, then check `ip route get 10.19.20.1` and `ping
10.19.20.1` on KingsCross. From an enrolled client in the source group, check
`ping 10.19.20.1` and TCP port 22. The gateway itself has already passed the
VPN-side check; client-side NetBird routing still needs activation to verify.
