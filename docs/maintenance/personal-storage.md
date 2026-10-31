# King'sCross personal storage

Configuration: `hosts/KingsCross/personal-storage/default.nix`; service implementation
and Python helpers live alongside it in `hosts/KingsCross/personal-storage/`.

| Service | HTTPS address | Account / access |
| --- | --- | --- |
| Transfer | `files.vps.seekerer.com:28443` | `transfer`: list, upload, download |
| Management | `files-internal.vps.seekerer.com:28443` | `manager`: also move/delete; NetBird only |
| LiveSync | `obsidian.vps.seekerer.com:28443` | `livesync`, database `obsidian` |

AliDNS has three static A records: `files.vps` and `obsidian.vps` point to
`36.140.30.163`; `files-internal.vps` points to `100.4.16.88`. No private DNS
zones are needed. ACME uses the existing AliDNS credentials for all three names.
The proxy overwrites forwarding headers and checks both source and destination
overlay addresses before allowing management access. CouchDB server administration
is available only through loopback/SSH, not the public proxy.

## Credentials and first sync

Passwords are in `hosts/KingsCross/personal-storage.secrets.yaml`:

```bash
sops --decrypt --extract '["transfer_password"]' \
  hosts/KingsCross/personal-storage.secrets.yaml
```

Other fields: `manager_password`, `livesync_password`, `couchdb_admin_password`.
sops-nix renders runtime configs; password updates restart the affected services.

Back up the Vault, configure Self-hosted LiveSync with the URL/account above,
and enable E2EE using a client-only passphrase saved in your password manager.
The server never receives that passphrase. After the first sync, use the
plugin's Setup URI on other devices. The sync account administers only its
own database; the server admin password is for local maintenance.

## Capacity and retention

The services share one ext4 project quota (ID `3500`) on
`/srv/personal-services`: 35 decimal GB, rounded down to a quota block, and
250,000 inodes. This includes partial uploads, database/index files, application
state, service logs and proxy temporary files. Nix packages/generations are
system storage outside this pool.

A Copyparty user quota protects CouchDB compaction headroom across HTTP and
SFTP. It changes with database usage; the two services have no fixed split.
Only quota setup/monitoring and CouchDB account bootstrap need Python helpers;
quota operations themselves use `quota` tools, not custom kernel bindings.

systemd-tmpfiles removes transfer files **three days after server-side creation**,
regardless of client-preserved timestamps or downloads. Cleanup runs every minute;
Copyparty rescans external changes. There is no separate expiry database.

Change `quotaGB` or `transferRetentionDays` in the host module and deploy normally:

```bash
nix run path:.#deploy-rs -- path:.#kingsCross
```

Quota changes apply online; unsafe shrinking is rejected without deleting data.
The root filesystem already has `quota,project` features and mounts with
`usrquota,prjquota`; initial preparation was completed on 2026-10-31. No special
maintenance boot or reboot is needed for routine changes.

```bash
personal-storage-status
personal-storage-logs -u copyparty -u couchdb -u personal-storage-sftp
systemctl status personal-storage-quota personal-storage-budget
```

## SFTP and mounted access

SFTP uses the system OpenSSH implementation on `100.4.16.88:2222`, key-only,
with the dedicated `copyparty` Unix account. Its chroot exposes only `/files`;
that directory is the same data shown on the web. No shell or forwarding is allowed.

Apply the client's normal Nix update to get the `transfer` alias and SSHFS.
Mihomo clients also get a DIRECT rule and fake-IP exclusion for the management
hostname. Until then use `scp -P 2222 -i ~/.ssh/id_mesh file copyparty@100.4.16.88:/files/`.

```bash
scp ./example.txt transfer:
scp transfer:example.txt ./
sshfs transfer: ~/transfer
mv ~/transfer/example.txt ~/Downloads/
fusermount3 -u ~/transfer
```

SFTP starts in `/files`, so use `transfer:` for its default directory, or
`transfer:/files/` explicitly. Cross-filesystem moves copy before deleting.
