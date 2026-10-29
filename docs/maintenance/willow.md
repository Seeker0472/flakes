# Willow Maintenance

Willow is the final Mihomo exit. It runs two listeners that forward accepted
traffic to `DIRECT`: Hysteria2 on UDP `28444` (primary) and Shadowsocks 2022
on TCP/UDP `28443` (fallback). Its NixOS module does not fetch airport
subscriptions or run TUN/DNS hijacking. The listeners, server address,
certificate fingerprint, and client rules are defined in
`hosts/Willow/mihomo.nix` and
`modules/profiles/programs/mihomo/willow.nix`; check those files for current
configured values.

## First install

The initial install erases the target disk. Run it only when that is intended.
Set `WILLOW_HOST` to the target configured in `outputs/deploy.nix`, and verify
it against the GCP instance before connecting:

```bash
WILLOW_HOST='<configured Willow address>'
cd /home/seeker/nixos-config
nix \
  --option substituters \
    'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option fallback true \
  run github:nix-community/nixos-anywhere -- \
  --flake "path:$PWD#Willow" \
  --target-host "seeker@$WILLOW_HOST" \
  -i /home/seeker/.ssh/id_external \
  --copy-host-keys
```

`--copy-host-keys` is required because Willow's SOPS identity derives from
`/etc/ssh/ssh_host_ed25519_key`. The initial Debian `seeker` account uses the
external bootstrap key; the installed system authorizes the administrator key.

## Routine deploy

```bash
nix run .#deploy-rs -- .#willow
```

Keep the provider console available while changing networking, SSH, the kernel,
or boot settings. Routine updates must not repartition the disk. The deploy
address is configured in `outputs/deploy.nix`; verify the live GCP address
before using it.

## GCP resources

The VM is `test` in project `main-512409`, zone `us-west1-b`. Its external
address is the regional static address `my-new-static-ip` (`8.229.8.238`), so
stopping or recreating the VM does not change the client configuration.
Firewall rule `willow-mihomo` controls the public inbound ports. The instance's
service account cannot read Compute resources; use Cloud Shell or a separately
authenticated `gcloud` to inspect them.

## GCP firewall

The NixOS firewall opens TCP/UDP `28443` and UDP `28444`; the GCP firewall
must also allow those ports. Use the correct project and VPC network for the
instance, and verify the rule in GCP before relying on it:

```bash
gcloud compute firewall-rules create willow-mihomo \
  --project='<GCP_PROJECT>' \
  --network='<VPC_NETWORK>' \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:28443,udp:28443,udp:28444 \
  --source-ranges=0.0.0.0/0 \
  --description='Willow Hysteria2 + Shadowsocks exit'
```

If the rule already exists, update it to allow all three ports:

```bash
gcloud compute firewall-rules update willow-mihomo \
  --project='<GCP_PROJECT>' \
  --rules=tcp:28443,udp:28443,udp:28444
```

## NetBird

Enabling `machine.programs.netbird` installs and starts the client but does not
enroll it. Use a setup key from the NetBird dashboard:

```bash
WILLOW_HOST='<configured Willow address>'
ssh "root@$WILLOW_HOST"
```

On Willow, enroll with a setup key from the NetBird dashboard:

```bash
netbird up \
  --management-url https://netbird.vps.seekerer.com:28443 \
  --setup-key '<SETUP_KEY>'
netbird status
```

Enrollment state is stored in `/var/lib/netbird`.

## Secrets

`hosts/Willow/mihomo.secrets.yaml` contains `willow_ss_password`,
`willow_hy2_password`, the Hysteria2 private key `willow_hy2_key`, and
`willow_controller_secret`. It is encrypted for admin, recovery, DiagonAlley,
and Willow's SSH host key. `willow_hy2_password` must match the copy in
`modules/profiles/programs/mihomo/mihomo.secrets.yaml` used by clients. Edit
either file from a machine with an authorized age key:

```bash
sops hosts/Willow/mihomo.secrets.yaml
```

The public certificate is `hosts/Willow/hysteria2.crt`; `willow.nix` pins its
SHA256 fingerprint. To rotate it, generate a certificate whose SAN matches
`hy2Sni`, replace the certificate, update `hy2Fingerprint`, store the new
private key as `willow_hy2_key`, and redeploy Willow and every client.

The Mihomo controller listens only on `127.0.0.1:9090`; tunnel it over SSH:

```bash
WILLOW_HOST='<configured Willow address>'
ssh -L 9090:127.0.0.1:9090 "root@$WILLOW_HOST"
```

If Willow's SSH host key is replaced, derive the new recipient with
`ssh-to-age -i <host-key>.pub`, update `willow_age` in `.sops.yaml`, then run:

```bash
sops updatekeys -y hosts/Willow/mihomo.secrets.yaml
```

## Client chain and verification

The shared client configuration in
`modules/profiles/programs/mihomo/willow.nix` defines two transports,
`WillowHY2` (Hysteria2 over UDP, primary) and `WillowSS` (Shadowsocks 2022 over
TCP with sing-mux, fallback), plus two groups: `Willow-Auto` (automatic HY2 ->
SS fallback) and `Willow` (a selector over Auto/HY2/SS). The client selects an
airport entry through `Chain-Entry` and uses `dialer-proxy` to reach Willow;
the listeners exit directly. The AI rules target `Willow` and have no `DIRECT`
fallback, so the transport can be pinned per client. IPv6 is disabled on
Mihomo clients and on Willow. UDP is enabled, so the selected airport must
relay UDP to `28444` for Hysteria2 and to `28443` for the Shadowsocks UDP
fallback.

Willow's mihomo service must allow `AF_NETLINK` in
`RestrictAddressFamilies`: UDP `DIRECT` needs to query the outbound route.
Without it, UDP/QUIC requests fail with `route ip+net: netlinkrib: address
family not supported by protocol` even though TCP works.

Verify the configured address and firewall before running these checks:

```bash
WILLOW_HOST='<configured Willow address>'
ssh "root@$WILLOW_HOST" 'systemctl status mihomo netbird --no-pager'
ssh "root@$WILLOW_HOST" 'ss -lntup | grep -E "28443|28444"'
nc -vz "$WILLOW_HOST" 28443
nc -vzu "$WILLOW_HOST" 28444
```

From a client with the Mihomo TUN enabled, verify the entire UDP chain:

```bash
curl --http3-only --noproxy '*' --connect-timeout 5 \
  -o /dev/null -w '%{http_version}\n' https://cdn.oaistatic.com/
```

The expected HTTP version is `3`; the CDN root may return HTTP 404.
