# Willow Maintenance

Willow is the GCP e2-micro VPS that will serve as the final exit of the
mihomo proxy chain. It runs only:

- OpenSSH, the NetBird client, and the base VPS tooling.
- mihomo with a Shadowsocks 2022 listener on TCP `28443`, sending all
  accepted traffic out `DIRECT`.

It deliberately does not fetch airport subscriptions, run TUN/fake-ip DNS, or
host any King'sCross service (NetBird server, TaskChampion, nginx/ACME).
The chain logic lives on the clients: the client mihomo profile connects
through a fixed airport entry and `dialer-proxy` to Willow, so the path is
`client -> airport -> Willow -> target`. OpenAI/Codex domains are routed to
Willow with no `DIRECT` fallback; IPv6 is disabled both in mihomo and on the
mihomo hosts.

## First install

The Debian image's `seeker` account has passwordless sudo. Initial
installation erases the disk, so only run it when that is intended:

```bash
cd /home/seeker/nixos-config
nix \
  --option substituters \
    'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option fallback true \
  run github:nix-community/nixos-anywhere -- \
  --flake "path:$PWD#Willow" \
  --target-host seeker@8.229.8.238 \
  -i /home/seeker/.ssh/id_external \
  --copy-host-keys
```

`--copy-host-keys` is required: Willow's SOPS identity is derived from
`/etc/ssh/ssh_host_ed25519_key`, and the existing Debian key is already the
`willow_age` recipient in `.sops.yaml`. The `external` key is only for the
bootstrap account; after installation, root and `seeker` authorize
`~/.ssh/id_admin`.

## Deploy

```bash
nix run .#deploy-rs -- .#willow
```

The deploy node uses `root@8.229.8.238`. Keep the GCP console reachable
while changing networking, SSH, the kernel, or the boot loader.

## GCP networking

The NixOS firewall opens the reserved `28400-28499` band, but GCP's firewall
is in front of it. Add an ingress rule for TCP `28443` (the instance has no
network tags, so a rule without target tags applies to it):

```bash
gcloud compute firewall-rules create willow-mihomo \
  --project=main-512409 \
  --network=default \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:28443 \
  --source-ranges=0.0.0.0/0 \
  --description="Willow Shadowsocks 2022 exit"
```

The VM's external address is currently `8.229.8.238`. It is not reserved;
if the address must survive VM recreation, reserve a static external IP and
update `outputs/deploy.nix` and the client configuration.

## NetBird

`machine.programs.netbird.enable` installs the client and starts the daemon
but does not enroll it. Enroll once with a setup key from the NetBird
dashboard:

```bash
ssh root@8.229.8.238
netbird up \
  --management-url https://netbird.vps.seekerer.com:28443 \
  --setup-key <setup-key>
netbird status
```

The enrollment state lives in `/var/lib/netbird`, which is on the persistent
root filesystem.

## Secrets

`hosts/Willow/mihomo.secrets.yaml` is encrypted to admin, recovery,
DiagonAlley, and the Willow host key:

- `willow_ss_password` — 32-byte base64 Shadowsocks 2022 pre-shared key.
- `willow_controller_secret` — mihomo REST API secret.

Edit from the admin/DiagonAlley machine:

```bash
sops hosts/Willow/mihomo.secrets.yaml
```

The REST API listens on `127.0.0.1:9090` only. Reach it through an SSH tunnel:

```bash
ssh -L 9090:127.0.0.1:9090 root@8.229.8.238
```

If the VM or its SSH host key is replaced, derive the new age recipient with
`ssh-to-age -i <host key>.pub`, replace `willow_age` in `.sops.yaml`, and run:

```bash
sops updatekeys -y hosts/Willow/mihomo.secrets.yaml
```

## Client chain

`modules/profiles/programs/mihomo/mihomo.nix` adds:

- a `Willow` Shadowsocks 2022 proxy using the shared
  `willow_ss_password` secret;
- a fixed `Chain-Entry` select group over `airport_ikuuu` (choose one node
  with good connectivity to GCP);
- fail-closed `DOMAIN-SUFFIX` rules for OpenAI/Codex/ChatGPT and their
  third-party assets, all targeting `Willow`;
- a remote-DoH policy for those domains, with `DOMAIN,dns.google,Willow`;
- `ipv6: false`, plus `networking.enableIPv6 = false` on hosts with mihomo.

The proxy entry is:

```yaml
proxies:
  - name: Willow
    type: ss
    server: 8.229.8.238
    port: 28443
    cipher: 2022-blake3-aes-256-gcm
    password: <willow_ss_password>
    udp: false
    dialer-proxy: Chain-Entry
```

`dialer-proxy` makes the airport node dial Willow, so the exit address seen
by targets is Willow's, while the local ISP only sees the airport connection.
The chain is TCP-only: airport relays may not forward UDP or TLS-camouflage
protocols correctly. Disable QUIC in the ChatGPT browser profile and keep
WebRTC disabled to avoid leaks.

Codex itself uses the official OpenAI endpoint (`codex login`), not the
allrouter relay. The OMP `claude-code` provider is the only remaining rustcat
consumer and uses `CLAUDE_CODE_API_KEY`.

The same rule set covers the native ChatGPT apps: `android.chat.openai.com`,
`desktop.chat.openai.com`, `ios.chat.openai.com`, and
`tcr9i.chat.openai.com` are under `*.openai.com`; `humb.apple.com` is the
macOS/iOS App Attest endpoint. The NixOS module only configures NixOS hosts;
a macOS or Android mihomo client must import the same `Willow` proxy,
`Chain-Entry` group, and domain rules. Text and WebSocket traffic is TCP and
works through the Shadowsocks chain; voice/UDP may need a UDP-capable relay.

## Verification

```bash
ssh root@8.229.8.238 'systemctl status mihomo netbird --no-pager'
ssh root@8.229.8.238 'ss -lntp | grep 28443'
nc -vz 8.229.8.238 28443   # after the GCP firewall rule exists
```
