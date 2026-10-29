# Willow profiles for Clash Verge / Mihomo

Nix generates the profiles from the shared data in
`modules/profiles/programs/mihomo/willow.nix`. The full profile sends all
non-local traffic through Willow; the Merge and Script variants add only the
configured AI-domain routes to an existing subscription.

## Build

Nix cannot decrypt SOPS during a pure build. Supply both passwords from
`hosts/Willow/mihomo.secrets.yaml`:

```bash
cd /home/seeker/nixos-config
WILLOW_SS_PASSWORD="$(sops -d --extract '["willow_ss_password"]' hosts/Willow/mihomo.secrets.yaml)" \
WILLOW_HY2_PASSWORD="$(sops -d --extract '["willow_hy2_password"]' hosts/Willow/mihomo.secrets.yaml)" \
  nix build --impure .#clash-verge-willow
```

`result/` contains `willow.yaml`, `willow-merge.yaml`, `willow-script.js`, and
this README. The generated profiles and Nix store contain the real passwords;
treat them as secrets and do not publish them. Without the impure environment
variables, Nix emits placeholder passwords.

## Choose a profile

### Full profile

1. Import `result/willow.yaml` as a local profile.
2. Enable TUN mode or System Proxy.
3. Select `Willow` in the `Chain` group. `Willow` is a selector with three
   choices: `Willow-Auto` (the default `WillowHY2` -> `WillowSS` fallback),
   `WillowHY2`, and `WillowSS`. `DIRECT` remains available as a bypass.

This profile connects directly to Willow, not through a private airport entry.
Test through the local mixed port and compare the returned `ip` to Willow's
configured public egress address:

```bash
curl -sS -x http://127.0.0.1:7897 \
  https://api.openai.com/cdn-cgi/trace
```

### Existing subscription

- **Merge:** add `result/willow-merge.yaml` to the subscription's Merge config.
- **Script:** paste `result/willow-script.js` into the subscription's Script
  config.

Both variants prepend the `WillowHY2` and `WillowSS` proxies, the `Willow`
selector, the `Willow-Auto` fallback, and the AI-domain rules; the subscription
continues to handle DNS/TUN and all other traffic.

The **Script** variant also adds a `Willow-Entry` selector built from the
subscription's proxy names and chains both transports through it. Choose the
entry node in `Willow-Entry`, then choose `Willow-Auto`, `WillowHY2`, or
`WillowSS` in `Willow`. The selector never contains `DIRECT`: if no subscription
proxies are discoverable it only contains `REJECT`, so AI traffic fails closed
instead of bypassing the entry.

The **Merge** variant cannot enumerate subscription nodes, so its proxies dial
Willow directly and there is no `Willow-Entry` group. Use the Script variant
when you need entry + transport selection.

## Notes

- The generated full profile uses mixed port `7897`, enables TUN, disables
  IPv6, and does not allow LAN clients. Adjust local test commands if the app
  uses a different port.
- Hysteria2 uses UDP `28444`; the Shadowsocks fallback uses TCP/UDP `28443`.
  UDP traffic also depends on the chosen network path relaying those ports.
- The Hysteria2 certificate is self-signed and pinned by SHA256 fingerprint
  from `willow.nix`; no CA is required. Rotating the certificate requires a new
  fingerprint in the repository.
- `Willow-Auto` is the default selection. Choosing `WillowHY2` or `WillowSS`
  pins that transport; the choice is stored by the profile
  (`store-selected: true`).
- The full profile routes all non-local traffic through Willow. Both transport
  passwords are shared and there is no per-user accounting; use trusted users
  or the AI-only Merge/Script variant.
- Clash Verge is desktop software. On Android, use a Mihomo-based client.
