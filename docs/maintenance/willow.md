# Willow Maintenance

Willow is configured as the final Mihomo exit: a Shadowsocks 2022 listener on
TCP/UDP port `28443` forwards accepted traffic to `DIRECT`. Its NixOS module
does not fetch airport subscriptions or run TUN/DNS hijacking. The listener,
server address, and client rules are defined in `hosts/Willow/mihomo.nix` and
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

## GCP firewall

The NixOS firewall opens TCP and UDP `28443`; the GCP firewall must also allow
that port. Use the correct project and VPC network for the instance, and verify
the rule in GCP before relying on it:

```bash
gcloud compute firewall-rules create willow-mihomo \
  --project='<GCP_PROJECT>' \
  --network='<VPC_NETWORK>' \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:28443,udp:28443 \
  --source-ranges=0.0.0.0/0 \
  --description='Willow Shadowsocks 2022 exit'
```

If the rule already exists, update it to allow both protocols:

```bash
gcloud compute firewall-rules update willow-mihomo \
  --project='<GCP_PROJECT>' \
  --rules=tcp:28443,udp:28443
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

`hosts/Willow/mihomo.secrets.yaml` contains `willow_ss_password` and
`willow_controller_secret`. It is encrypted for admin, recovery, DiagonAlley,
and Willow's SSH host key. Edit it from a machine with an authorized age key:

```bash
sops hosts/Willow/mihomo.secrets.yaml
```

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
`modules/profiles/programs/mihomo/willow.nix` defines the Willow proxy and the
AI-domain rules. The client selects an airport entry through `Chain-Entry` and
uses `dialer-proxy` to reach Willow; the Willow listener exits directly. The
AI rules have no `DIRECT` fallback. IPv6 is disabled on Mihomo clients and on
Willow. UDP is enabled, so the selected airport must relay UDP for UDP traffic
to work.

Verify the configured address and firewall before running these checks:

```bash
WILLOW_HOST='<configured Willow address>'
ssh "root@$WILLOW_HOST" 'systemctl status mihomo netbird --no-pager'
ssh "root@$WILLOW_HOST" 'ss -lntup | grep 28443'
nc -vz "$WILLOW_HOST" 28443
```
