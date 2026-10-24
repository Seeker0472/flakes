# Secret Management

SOPS uses two human-managed age identities:

- `admin_seeker_age` is installed on `miLaptop` and `nixos-wsl` for daily editing.
- `recovery_age` is kept offline and is a recipient for every encrypted file.

`devVM`, `DiagonAlley`, `Hippogriff`, and `burrow` have separate runtime
identities. `devVM`
and `DiagonAlley` can decrypt their own SSH client key and the shared secrets
consumed by that host. `DiagonAlley`, `Hippogriff`, and `burrow` also receive
the administrator SSH key so they retain VPS maintenance access.
`Hippogriff` additionally consumes the shared external/GitHub keys, the AI
provider credentials, the shared nix configuration, the Taskwarrior pair, and
the shared Mihomo configuration. `Willow` has a host-scoped
`hosts/Willow/mihomo.secrets.yaml` and does not receive the shared airport
subscriptions. `burrow`
deliberately does not
receive the shared external, GitHub, or AI provider credentials.
`gpu01` has a separate runtime identity, scoped to the shared external and
GitHub keys plus the shared AI provider credentials (Claude Code and
DeepSeek).
The `mi15` and `miPad` nix-on-droid environments each have a dedicated runtime
identity. They can decrypt the same SSH and AI provider secrets as `miLaptop`,
but their age private keys are kept separately so either Android device can be
revoked without changing the other one.
`King'sCross` has no age key file: its identity is derived from the VPS SSH host
key (`sops.age.sshKeyPaths` in `hosts/KingsCross/netbird.nix`), so
`kings_cross_age` must equal the `ssh-to-age` form of
`/etc/ssh/ssh_host_ed25519_key` on the VPS. When the machine or its host key is
replaced, refresh the anchor in `.sops.yaml` and run `sops updatekeys -y` on
`hosts/KingsCross/netbird.secrets.yaml` and
`users/seeker/taskwarrior.secrets.yaml`.

`Willow` likewise has no age key file: `hosts/Willow/mihomo.nix` reads the VPS
SSH host key, so `willow_age` must equal its `ssh-to-age` form. The initial
`nixos-anywhere` install copies the Debian host key with `--copy-host-keys`.
`hosts/Willow/mihomo.secrets.yaml` holds the Shadowsocks 2022 password and the
mihomo controller secret. If the VM or host key is replaced, refresh the anchor
in `.sops.yaml` and run `sops updatekeys -y hosts/Willow/mihomo.secrets.yaml`.

The bootstrap identities live under the git-ignored `.secrets/age/` directory.
The SOPS identity itself must be installed out of band because it cannot decrypt
itself.

## SSH layout

- `users/seeker/ssh/<host>.secrets.json` contains one host-specific client key.
- `users/seeker/ssh/external.secrets.json` contains the shared default key for
  outbound SSH to external machines.
- `users/seeker/ssh/github.secrets.json` contains the single GitHub key shared by
  the four managed development clients.
- `users/seeker/ssh/admin.secrets.json` retains the existing administrator key and is
  deployed to `DiagonAlley`, `burrow`, `miLaptop`, `nixos-wsl`, `Hippogriff`,
  `mi15`, and
  `miPad`.
- `gpu01` receives the four development public keys in `authorized_keys` and
  the shared external and GitHub private keys, but no mesh or administrator
  private key.

Public keys use the `_unencrypted` suffix inside their SOPS documents. They are
not confidential, and keeping them readable lets NixOS and the standalone
gpu01 Home Manager configuration build `authorized_keys` without decrypting a
private key. SOPS still remains the single source for each key pair.

## AI provider credentials

`users/seeker/ai.secrets.json` holds only:

- `claude_code_api_key` — allrouter.cc key used by OMP's `claude-code` provider
- `deepseek_official_api_key` — official DeepSeek API (`api.deepseek.com`)

Edit the secrets file with:

```bash
sops users/seeker/ai.secrets.json
```

When `programs.ai.enable` is set, Home Manager installs:

- Codex (`agents.codex`) and, with `programs.ai.omp.enable`, OMP
  (`agents.omp`).
- `~/.omp/agent/models.yml` with only `deepseek-official` and `claude-code`.
- Session variables `CLAUDE_CODE_API_KEY` and `DEEPSEEK_OFFICIAL_API_KEY` from
  the `ai-env` template.

The keyless development container forces `programs.ai.enable` off. `burrow`
does not receive these credentials.

## Taskwarrior synchronization

`users/seeker/taskwarrior.secrets.yaml` contains the shared TaskChampion
client ID and client-side encryption secret. Home Manager renders them into a
mode `0400` Taskwarrior configuration fragment on `miLaptop` and
`DiagonAlley`. King'sCross reads only the client ID to restrict the sync
server; the encryption secret is not passed to the server process.

`miLaptop` is the primary replica for recurring tasks. `DiagonAlley` and
`Hippogriff` disable
recurrence generation to avoid duplicate recurring tasks while retaining full
sync and task editing support.

## Bootstrap

Install the admin identity at
`/persist/home/seeker/.config/sops/age/keys.txt` on `miLaptop` and at
`~/.config/sops/age/keys.txt` on `nixos-wsl`. The miLaptop persistence mount
also exposes its identity at the standard XDG path after boot. Install
`.secrets/age/devVM.txt` at `~/.config/sops/age/keys.txt` inside devVM before
activating a configuration that consumes secrets. Install
`.secrets/age/gpu01.txt` at the same path on gpu01. Keep
`.secrets/age/recovery.txt` offline after confirming that it decrypts the
repository.

Install the dedicated DiagonAlley identity from
`.secrets/age/DiagonAlley.txt` out of band at
`/persist/home/seeker/.config/sops/age/keys.txt` before its first activation.

For nix-on-droid, install `.secrets/age/mi15.txt` at
`~/.config/sops/age/keys.txt` on MI15 and `.secrets/age/miPad.txt` at the same
path on MiPad before the first `nix-on-droid switch`. The flake outputs are
`nixOnDroidConfigurations.mi15` and `nixOnDroidConfigurations.miPad`, so the
device commands are:

```bash
nix-on-droid switch --flake path:/path/to/nixos-config#mi15
nix-on-droid switch --flake path:/path/to/nixos-config#miPad
```

The nix-on-droid environment is configured with the `seeker` username; the
underlying Android app UID remains managed by Android. It does not provide a
system OpenSSH daemon, so these configurations manage outbound SSH client
access only.

Willow needs no manual identity install: the `nixos-anywhere --copy-host-keys`
step preserves the host key that `willow_age` was derived from. See
`docs/maintenance/willow.md` for the install, GCP firewall, and NetBird
enrollment steps.

Install the dedicated burrow identity from `.secrets/age/burrow.txt` out of
band at `/home/seeker/.config/sops/age/keys.txt` before its first activation.
It decrypts only the shared Mihomo configuration and the administrator SSH key
selected for VPS maintenance. Wi-Fi credentials remain in NetworkManager's
local persistent connection profile and are not managed by SOPS.

Install the dedicated Hippogriff identity from `.secrets/age/Hippogriff.txt`
out of band at `/home/seeker/.config/sops/age/keys.txt` (owner `seeker`, mode
`0600`) before its first activation. It decrypts its own SSH client key, the
shared external and GitHub keys, the administrator SSH key, the AI provider
credentials, the shared nix configuration, and the Taskwarrior sync pair. See
`docs/maintenance/hippogriff.md` for the build, update, and rollback workflow.

Before the first activation on an existing `miLaptop`, copy the old
`/persist/home/seeker/age/keys` identity to
`/persist/home/seeker/.config/sops/age/keys.txt`, owned by `seeker` with mode
`0600`. The system reads this backing path before regular local filesystems and
user persistence mounts are available during activation.

See `docs/maintenance/devvm.md` for the devVM bootstrap, update, verification,
and rollback workflow.

Register the value of `public_key_unencrypted` from
`users/seeker/ssh/github.secrets.json` as the one GitHub authentication key.
Register the value from `users/seeker/ssh/external.secrets.json` on external
machines; the external key is intentionally separate from the GitHub key.
The gpu01 Home Manager activation takes ownership of `~/.ssh/authorized_keys`
and atomically installs a user-owned regular file containing the administrator
key plus the three development client keys. It deliberately does not use a Nix
store symlink because the cluster's shared store ownership fails OpenSSH
`StrictModes`. Confirm that no separately managed cluster key must be retained
before the first activation.

After changing recipients in `.sops.yaml`, update an existing document with:

```bash
sops updatekeys -y path/to/file.secrets.yaml
```
