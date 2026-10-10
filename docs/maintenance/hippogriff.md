# Hippogriff (Xiaomi Pad 6 Pro, liuqin)

Hippogriff is the Xiaomi Pad 6 Pro (`xiaomi,liuqin`, SM8475, aarch64). The
community port is consumed as the `liuqin` flake input
(`github:Seeker0472/liuqin-nixos`); its builder injects the hardware module,
the package overlay and the device packages from the port's x86_64→aarch64
cross set. The tablet keeps Android in `userdata` and boots NixOS from the
`linux` partition through U-Boot's extlinux generation menu.

## Build

The port builds the kernel and device packages in its cross set; only the
per-machine derivations (/etc, units, initrd) are aarch64 and need binfmt (or
the device itself). On a host with aarch64 binfmt enabled:

```bash
nix build .#nixosConfigurations.Hippogriff.config.system.build.toplevel
```

## Deploy

`nixos-rebuild` is not used on this device: the tablet has no nixpkgs source
and no channel. The port's update flow (liuqin-nixos `docs/INSTALL.md` §4)
applies with the host name substituted:

```bash
# host: build the closure and the loader script
nix build .#nixosConfigurations.Hippogriff.config.system.build.toplevel --out-link result-hippogriff
LOADER=$(nix eval --raw .#nixosConfigurations.Hippogriff.config.system.build.installBootLoader)

# host: push both to the tablet. Use the LEGACY ssh:// store: the ssh-ng
# store refuses locally built (unsigned) paths on the tablet with
# "lacks a signature by a trusted key" even though the machine user is in
# nix.settings.trusted-users; ssh:// (nix-store --serve) accepts them.
NIX_SSHOPTS="-i ~/.ssh/id_liuqin" \
  nix copy --to ssh://liuqin@192.168.11.132 \
    "$(readlink -f result-hippogriff)" "$LOADER"
```

```bash
# tablet, as root: profile first, then the loader, then switch, then reboot
N=/run/current-system/sw/bin
TO=$(ls -d /nix/store/*-nixos-system-Hippogriff-* | tail -1)   # or the pushed path
$N/nix-env --profile /nix/var/nix/profiles/system --set "$TO"
$LOADER "$TO"
"$TO/bin/switch-to-configuration" switch   # boot works too; a reboot follows
systemctl reboot
```

The loader step is mandatory: `switch-to-configuration` never touches the
bootloader, so `/boot/extlinux/extlinux.conf` (and the generation's kernel,
initrd and DTB next to it) are only installed by the loader script. Keep the
profile-setting before it — the builder keeps eight generations and reads them
from the profile link.

Rollback is the U-Boot menu's "NixOS Generations" entry.

## Secrets

Install the age identity from `.secrets/age/Hippogriff.txt` at
`/home/seeker/.config/sops/age/keys.txt` (owner `seeker`, mode `0600`) before
the first activation that consumes secrets; without impermanence this is the
only path sops-nix reads.

## Notes

- Enabled dev-machine services (2026-10-10): GNOME, KDE Connect, mihomo
  (share/tun/web), NetBird, Docker, GnuPG (pinentry-qt), fcitx5 (wayland,
  Chinese addons), Zed, kitty, zen-browser, plus the office/media app set
  (`users/seeker/packages/office.nix`, mpv, netease-cloud-music-gtk, zotero).
  obsidian, qq and vscode are x86_64-linux only in nixpkgs and cannot be
  enabled on this host (vscodium is available as an editor substitute).
- Docker: the port kernel already carries what containers need —
  `CONFIG_NF_TABLES=y` (built-in, so no nf_tables.ko) with NFT_NAT/NFT_MASQ/
  NFT_REDIR and nf_nat as modules, bridge/veth/br_netfilter, the built-in
  overlayfs and cgroups/namespaces/seccomp (verified against the running
  kernel 2026-10-10; the NixOS firewall is active on the same nftables
  backend). VXLAN, which `docker network create --driver overlay` and swarm
  mode need, was the one gap; the port enables it in commit 2987781 and the
  first system built from the bumped `liuqin` input picks it up. NetBird needs
  a runtime enrollment (`netbird up --setup-key ...`), mihomo reads its
  configuration from the sops secret.
- `/nix/store` comes up read-only from the initrd, but store writes still
  work: after boot, `nix-store --add-fixed` on the tablet succeeded with the
  mount left untouched (verified 2026-10-10), so `nix copy` and the deploy
  flow do not need a remount.
- Deployment automation (e.g. deploy-rs) must run the extlinux loader step
  after setting the profile; a plain `switch-to-configuration` deployment
  leaves `/boot` stale and the next boot picks the previous generation.
- The `seeker` account's SSH authorized keys include the sops-managed
  administrator/client keys plus the port demo's `id_liuqin` pubkey; the
  latter can be dropped once the managed keys are in use.
- Other hosts pick up this machine's new client key (`Hippogriff.secrets.json`
  in `users/seeker/ssh-public-keys.nix`) on their next activation.
