# Willow profiles for Clash Verge / Mihomo

Nix generates the profiles from the shared data in
`modules/profiles/programs/mihomo/willow.nix`. The full profile sends all
non-local traffic through Willow; the Merge and Script variants add only the
configured AI-domain routes to an existing subscription.

## Build

Nix cannot decrypt SOPS during a pure build. Supply the Shadowsocks password
from `hosts/Willow/mihomo.secrets.yaml`:

```bash
cd /home/seeker/nixos-config
WILLOW_SS_PASSWORD="$(sops -d hosts/Willow/mihomo.secrets.yaml \
  | awk -F': ' '/^willow_ss_password:/ {print $2}' | tr -d '\"')" \
  nix build --impure .#clash-verge-willow
```

`result/` contains `willow.yaml`, `willow-merge.yaml`, `willow-script.js`, and
this README. The generated profiles and Nix store contain the real password;
treat them as secrets and do not publish them. Without the impure environment
variable, Nix emits a placeholder password.

## Choose a profile

### Full profile

1. Import `result/willow.yaml` as a local profile.
2. Enable TUN mode or System Proxy.
3. Select `Willow` in the `Chain` group; `DIRECT` is available as a bypass.

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

Both variants prepend the Willow proxy and AI-domain rules; the subscription
continues to handle DNS/TUN and all other traffic. The AI rules do not fall
back to `DIRECT`.

## Notes

- The generated full profile uses mixed port `7897`, enables TUN, disables
  IPv6, and does not allow LAN clients. Adjust local test commands if the app
  uses a different port.
- The server and client require TCP and UDP `28443`; UDP also depends on the
  chosen network path relaying it.
- The full profile routes all non-local traffic through Willow. It shares one
  password and has no per-user accounting; use trusted users or the AI-only
  Merge/Script variant.
- Clash Verge is desktop software. On Android, use a Mihomo-based client.
