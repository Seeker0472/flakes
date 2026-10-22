# Willow for Clash Verge

These profiles use the Willow Shadowsocks 2022 exit at
`8.229.8.238:28443`. They connect **directly** to Willow; the owner's
private airport entry is intentionally not included.

Pick one:

| File | Use case |
| --- | --- |
| `willow.yaml` | User has no config at all. All traffic goes through Willow. |
| `willow-merge.yaml` | User already has a Clash subscription; only OpenAI/Codex domains go to Willow. |
| `willow-script.js` | Same as the merge, for Clash Verge's Script override. |

## Fill in the password

The files contain `<WILLOW_SS_PASSWORD>`. On the owner's machine:

```bash
cd /home/seeker/nixos-config
pw=$(sops -d hosts/Willow/mihomo.secrets.yaml \
  | awk -F': ' '/^willow_ss_password:/ {print $2}' | tr -d '"')

sed "s|<WILLOW_SS_PASSWORD>|$pw|g" \
  docs/clients/clash-verge/willow.yaml \
  > /tmp/willow-clash-verge.yaml
chmod 600 /tmp/willow-clash-verge.yaml
```

Do the same for `willow-merge.yaml` or `willow-script.js` if needed. The
filled file contains the shared SS password: send it only to trusted users,
and rotate `willow_ss_password` (then redeploy Willow) if it leaks.

## Full profile (nothing configured)

1. Clash Verge -> Profiles -> `+` -> Local (or URL, if you host the filled
   file privately).
2. Select `willow-clash-verge.yaml`.
3. Enable **Tun Mode** (recommended) or **System Proxy**.
4. The `Chain` group defaults to `Willow`. `DIRECT` is available if the user
   wants to bypass.
5. Test from a terminal:

```bash
curl -sS -x http://127.0.0.1:7897 https://api.openai.com/cdn-cgi/trace
```

Expected:

```text
ip=8.229.8.238
loc=US
```

The full profile sends **all** traffic through Willow. To make it AI-only,
replace the last rule `MATCH,Chain` with the OpenAI rules from
`willow-merge.yaml` followed by `MATCH,DIRECT`.

## Merge / Script (existing subscription)

For a user who already has a subscription profile:

- **Merge**: Profiles -> the subscription -> Merge -> paste/import
  `willow-merge.yaml`. It prepends `Willow`, the `Willow-Chain` group, and
  the OpenAI/Codex rules; the base profile handles everything else.
- **Script**: Profiles -> the subscription -> Script -> paste
  `willow-script.js`. It prepends the same proxy, group, and rules to the
  loaded config.

The `Willow-Chain` group defaults to `Willow`; `DIRECT` can bypass. The base
profile's DNS/TUN settings remain in effect. Test with the same `curl`
command; the OpenAI/Codex domains should show `ip=8.229.8.238`.

## Full chain / entry hop

The owner's own chain is `client -> airport -> Willow`. The airport
subscription is private and must not be shared. These profiles therefore go
directly to Willow. If a user's network cannot reach Willow, add a dedicated
entry proxy that you are allowed to share:

```yaml
proxies:
  - name: Entry
    type: ss
    server: <ENTRY_SERVER>
    port: <ENTRY_PORT>
    cipher: <ENTRY_CIPHER>
    password: "<ENTRY_PASSWORD>"
    udp: true

  - name: Willow
    # ...
    dialer-proxy: Entry
```

Do not put your airport subscription URL in a public profile.

## Notes

- Clash Verge Rev uses the Mihomo core and supports
  `2022-blake3-aes-256-gcm`.
- The full profile sets `mixed-port: 7897` (Clash Verge's usual mixed port).
  If the app uses a different port, adjust the test command.
- TUN/system proxy must be enabled in the app; the profile cannot force the
  app's global switch.
- `ipv6: false` is set in the profile; Willow is IPv4-only.
- `udp: true` is set on Willow; the server and GCP firewall must allow both
  TCP and UDP `28443`. If the user's network blocks UDP, TCP still works.
- The full profile sends all traffic through Willow. For limited bandwidth,
  use the merge/script AI-only variant or restrict the user set; the password
  is shared and has no per-user accounting.
- On Android, use a Mihomo-based client such as Clash Meta/FlClash with
  `willow.yaml`; Clash Verge itself is desktop (macOS/Windows/Linux).
