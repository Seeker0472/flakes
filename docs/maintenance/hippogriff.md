# Hippogriff (Xiaomi Pad 6 Pro, liuqin)

Hippogriff is the Xiaomi Pad 6 Pro (`xiaomi,liuqin`, SM8475, aarch64). The
community port is consumed as the `liuqin` flake input. Two configurations
share the same hardware, tablet bundle and user modules:

- `Hippogriff` applies the port overlay directly. Device packages are native
  aarch64, so the tablet can build and replace its own boot chain.
- `HippogriffFast` additionally applies `overlay-inject.nix` with
  `liuqin.lib.pkgsArm`. The manifest's kernel, U-Boot, firmware and sensor
  packages are host-built x86_64→aarch64 outputs; the remaining system stays
  native aarch64.

The tablet keeps Android in `userdata` and boots NixOS from the `linux`
partition through U-Boot's extlinux generation menu.

## Build

The release configuration builds device packages on the tablet, or through
binfmt on an x86_64 host with qemu-user:

```bash
nix build .#nixosConfigurations.Hippogriff.config.system.build.toplevel
```

For the host-built profile used by the fast deploy node:

```bash
nix build .#deploy.nodes.hippogriff-fast.profiles.system.path \
  --out-link result-hippogriff-fast
```

Deploy with deploy-rs:

```bash
# Native device packages; supports --remote-build.
nix run .#deploy-rs -- .#hippogriff

# Injected cross-built device packages; build on the host.
nix run .#deploy-rs -- .#hippogriff-fast
```

Both nodes use ssh-ng as `seeker` and activate with
`switch-to-configuration switch`; interactive sudo prompts once. The tablet
trusts `seeker` for unsigned device packages. Their configured target is in
`outputs/deploy.nix`; verify it before use and pass `--hostname <address>` if
the configured target is stale.

For `hippogriff`, `--remote-build` lets the tablet build its native device
packages; without it the x86_64 host uses binfmt. Both routes realise the same
store paths. Do not pass `--remote-build` to `hippogriff-fast`: its injected
device derivations come from the port's x86_64 cross package set and are
intended to be realised on the host before copying the closure.

`switch-to-configuration` runs `installBootLoader` for both `switch` and
`boot`, writing the kernel, initrd, DTB, and extlinux menu. deploy-rs
magicRollback handles lost SSH; the U-Boot NixOS Generations menu is the local
recovery path. `--dry-activate` runs activation without setting the profile.

## Fallback: manual push and activation

Use this only when deploy-rs is unavailable, especially for a generation that
changes the kernel. Verify the tablet address before copying:

```bash
TABLET_HOST='<verified tablet address>'
nix build .#nixosConfigurations.Hippogriff.config.system.build.toplevel \
  --out-link result-hippogriff
LOADER=$(nix eval --raw .#nixosConfigurations.Hippogriff.config.system.build.installBootLoader)
TO=$(readlink -f result-hippogriff)
printf 'SYSTEM_PATH=%s\nLOADER=%s\n' "$TO" "$LOADER"

NIX_SSHOPTS="-i $HOME/.ssh/id_admin" \
  nix copy --to "ssh-ng://seeker@$TABLET_HOST" "$TO" "$LOADER"
```

On the tablet, as root, set `TO` and `LOADER` to the printed store paths:

```bash
N=/run/current-system/sw/bin
TO='<printed SYSTEM_PATH>'
LOADER='<printed LOADER path>'
$N/nix-env --profile /nix/var/nix/profiles/system --set "$TO"
"$LOADER" "$TO"
```

For an ordinary generation, finish with:

```bash
"$TO/bin/switch-to-configuration" switch
```

For the first generation with a new kernel, stop after installing the loader
and reboot instead; do not restart services under the old running kernel.
`systemctl reboot`

## Secrets

See [SECRETS.md](../../SECRETS.md) for identity setup. Install the age identity
from `.secrets/age/Hippogriff.txt` at
`/home/seeker/.config/sops/age/keys.txt` (owner `seeker`, mode `0600`) before
the first activation that consumes secrets; without impermanence this is the
only path sops-nix reads.
