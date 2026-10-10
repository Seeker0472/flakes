# Hippogriff (Xiaomi Pad 6 Pro, liuqin)

Hippogriff is the Xiaomi Pad 6 Pro (`xiaomi,liuqin`, SM8475, aarch64). The
community port is consumed as the `liuqin` flake input
(`github:Seeker0472/liuqin-nixos`); `outputs/nixos-configurations.nix` applies
its hardware module and package overlay and deliberately leaves the device
packages (kernel, U-Boot, firmware) native aarch64 instead of injecting the
port's x86_64→aarch64 cross set, so the tablet can build and replace its own
boot chain. The tablet keeps Android in `userdata` and boots NixOS from the
`linux` partition through U-Boot's extlinux generation menu.

## Build

The kernel and the other device packages (U-Boot, firmware, sensors) are
native aarch64 derivations, like the per-machine ones (/etc, units, initrd,
images): they build on the tablet itself, or through binfmt on an x86_64 host
with qemu-user. Compiling the kernel under emulation is slow; deploys build
here by default, and `--remote-build` (see [Deploy](#deploy)) makes the tablet
build instead:

```bash
nix build .#nixosConfigurations.Hippogriff.config.system.build.toplevel
```

## Deploy

Deploy with deploy-rs - the default path for routine updates:

```bash
nix run .#deploy-rs -- .#hippogriff
```

It builds locally (binfmt runs the aarch64 device packages here - slow for the
kernel - while the unmodified parts come from cache.nixos.org), pushes the
closure to `seeker@192.168.11.132` over the ssh-ng store, sets
`/nix/var/nix/profiles/system` and activates with `switch-to-configuration
switch`, prompting once for the account's sudo password (`interactiveSudo`).
The unsigned device packages are accepted because `seeker` is in the tablet's
`nix.settings.trusted-users` (`hosts/Hippogriff/default.nix`). Passing
`--remote-build` lets the tablet build its own closure instead: only the
derivation crosses the wire and nothing unsigned is copied. The CLI flag can
only turn this on for one invocation, not off; `mkNode`'s `remoteBuild`
argument enables it per node. Both routes realise the same store paths, so
mixing them does not rebuild what the other side already has.
`switch-to-configuration` is the NG implementation here and runs the extlinux
loader (`system.build.installBootLoader`) for `switch` and `boot` alike, so
the generation's kernel, initrd, DTB and menu entry are written by the
activation itself. deploy-rs' magicRollback reverts the profile when the
activation loses the SSH connection; rollback is also the U-Boot menu's
"NixOS Generations" entry (eight generations are kept).

`--dry-activate` runs the activation without setting the profile.

The node's `hostname` in `flake.deploy` is only the current DHCP lease; pass
`--hostname <address>` when it moves (TODO: NetBird overlay address, see
`.todo.md`).

### Fallback: manual push and activation

The flow used before deploy-rs was wired up stays valid, and is the way in
when deploy-rs is unavailable:

```bash
# host: build the closure and the loader script
nix build .#nixosConfigurations.Hippogriff.config.system.build.toplevel --out-link result-hippogriff
LOADER=$(nix eval --raw .#nixosConfigurations.Hippogriff.config.system.build.installBootLoader)

# host: push both to the tablet (the machine user is trusted for the ssh-ng
# store, so locally built unsigned paths are accepted; ssh:// works as well)
NIX_SSHOPTS="-i ~/.ssh/id_admin" \
  nix copy --to ssh-ng://seeker@192.168.11.132 \
    "$(readlink -f result-hippogriff)" "$LOADER"
```

```bash
# tablet, as root: profile, loader, switch, reboot
N=/run/current-system/sw/bin
TO=/nix/store/<hash>-nixos-system-Hippogriff-<version>   # the pushed path
$N/nix-env --profile /nix/var/nix/profiles/system --set "$TO"
"$LOADER" "$TO"        # switch would install it too; profile → loader → switch stays the safe order
"$TO/bin/switch-to-configuration" switch
systemctl reboot
```

When the generation changes the kernel (as the first one carrying the Docker
NAT targets does), stop after the loader step and reboot: `switch` would
restart services under the running old kernel first, and a service the old
kernel cannot run (dockerd without the xt NAT targets) fails the activation,
which deploy-rs answers with a rollback. The profile and the loader entry are
already written, so the reboot boots the new kernel and the new generation.

## Secrets

Install the age identity from `.secrets/age/Hippogriff.txt` at
`/home/seeker/.config/sops/age/keys.txt` (owner `seeker`, mode `0600`) before
the first activation that consumes secrets; without impermanence this is the
only path sops-nix reads.

## Notes

- Enabled dev-machine services (2026-10-10): GNOME, KDE Connect, mihomo
  (share/tun/web), NetBird, Docker, GnuPG (pinentry-qt), fcitx5 (wayland,
  Chinese addons), Zed, kitty, zen-browser, the office set
  (`users/seeker/packages/office.nix`), the light media set
  (`users/seeker/packages/media.nix`: mpv, viewnior, gimp3, gtkwave, surfer,
  cava), netease-cloud-music-gtk, zotero, obsidian, qq, vscode, and the
  shared MIME defaults from `users/seeker/xdg_default.nix`. obsidian, qq and
  vscode do have aarch64-linux builds in this nixpkgs revision
  (`meta.platforms`, checked 2026-10-10), so the earlier "x86_64-only" note
  no longer applies; they are unfree, so there is no aarch64 build on
  cache.nixos.org and the first deploy builds them on the tablet (which
  `remoteBuild = true` does anyway). `users/seeker/packages/media-heavy.nix`
  (obs-studio) stays out: this machine is not meant for heavy capture
  workloads.
- Fonts: `sarasa-gothic` and `maple-mono.NF-CN` plus the laptop profile's
  fontconfig defaults (Noto Sans/Serif CJK SC, Maple Mono NF CN, Noto Color
  Emoji). Without them plain sans-serif/monospace requests resolve to
  DejaVu, which has no CJK metrics and no Nerd Font glyphs for kitty/zed.
- Docker: the port kernel carries the container stack's requirements —
  `CONFIG_NF_TABLES=y` (built-in, so no nf_tables.ko) with NFT_NAT/NFT_MASQ/
  NFT_REDIR and nf_nat as modules, bridge/veth/br_netfilter, the built-in
  overlayfs and cgroups/namespaces/seccomp (verified against the running
  kernel 2026-10-10; the NixOS firewall is active on the same nftables
  backend), VXLAN for `docker network create --driver overlay` (port commit
  2987781) — and, since port commit 4c02087, the two xt targets Docker's
  iptables client needs: `CONFIG_NETFILTER_XT_TARGET_MASQUERADE` and
  `CONFIG_NETFILTER_XT_NAT`. Docker's client is iptables-nft (there are no
  ip_tables/ip6_tables modules), and iptables-nft emulates `-j MASQUERADE`
  and DNAT through nft_compat, which fails unless the module registering the
  xt target exists; the nft nat/masq set above only serves rules written as
  native nft expressions. Without the two, dockerd 29.8.1 cannot start at
  all — measured 2026-10-10: "Warning: Extension MASQUERADE revision 0 not
  supported, missing kernel module?", then `RULE_INSERT failed (No such file
  or directory): rule in chain POSTROUTING`, then "error creating default
  \"bridge\" network: Failed to Setup IP tables: Unable to enable NAT rule".
  The same failure is what makes a deploy-rs run roll back while the running
  kernel predates 4c02087: switch-to-configuration restarts docker.service,
  it fails under the old kernel, and activation reports the failed unit. A
  kernel change needs a reboot anyway, so the first generation carrying the
  fix goes in with the manual push and `installBootLoader` path below plus
  `systemctl reboot`; deploy-rs works normally once the new kernel runs.
  NetBird needs a runtime enrollment (`netbird up --setup-key ...`), mihomo
  reads its configuration from the sops secret.
- `/nix/store` comes up read-only from the initrd, but store writes still
  work: after boot, `nix-store --add-fixed` on the tablet succeeded with the
  mount left untouched (verified 2026-10-10), so `nix copy` and the deploy
  flow do not need a remount.
- `switch-to-configuration` on this system is the NG implementation: it
  installs the bootloader for `switch` *and* `boot`
  (`if matches!(action, Switch | Boot) { do_install_bootloader(...) }`), which
  is why a plain deploy-rs activation is enough here. The port's INSTALL.md
  statement that the loader must be run separately applies to the older Perl
  implementation the port was written against.
- The `seeker` account's SSH authorized keys include the sops-managed
  administrator/client keys plus the port demo's `id_liuqin` pubkey; the
  latter can be dropped once the managed keys are in use.
- Other hosts pick up this machine's new client key (`Hippogriff.secrets.json`
  in `users/seeker/ssh-public-keys.nix`) on their next activation.
