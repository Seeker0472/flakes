# Secret management

SOPS recipients and file formats are defined in `.sops.yaml`. Private age keys
live in the git-ignored `.secrets/age/` directory and must be provisioned
out-of-band; an identity cannot decrypt itself.

## Identities and access

- `admin_seeker_age`: daily editing identity on `miLaptop` and `nixos-wsl`.
- `recovery_age`: offline recovery identity and recipient for every encrypted
  file.
- Runtime identities: `devVM`, `gpu01`, `DiagonAlley`, `Hippogriff`, `burrow`,
  `mi15`, and `miPad`. Each is stored separately and can be revoked separately.
- `King'sCross` and `Willow` derive their age identity from
  `/etc/ssh/ssh_host_ed25519_key`; neither uses a separate age key file.

The main SOPS scopes are:

| Encrypted file | Machine identities that can decrypt it |
| --- | --- |
| `users/seeker/ssh/admin.secrets.json` | DiagonAlley, burrow, Hippogriff, mi15, miPad; also admin and recovery |
| `users/seeker/ssh/external.secrets.json`, `github.secrets.json` | devVM, gpu01, DiagonAlley, Hippogriff, mi15, miPad; also admin and recovery |
| `users/seeker/ssh/devVM.secrets.json` | devVM; also admin and recovery |
| `users/seeker/ssh/DiagonAlley.secrets.json` | DiagonAlley; also admin and recovery |
| `users/seeker/ssh/Hippogriff.secrets.json` | Hippogriff; also admin and recovery |
| `users/seeker/ssh/miLaptop.secrets.json` | mi15, miPad; also admin and recovery |
| `users/seeker/ai.secrets.json` | devVM, gpu01, DiagonAlley, Hippogriff, mi15, miPad; also admin and recovery |
| `users/seeker/taskwarrior.secrets.yaml` | King'sCross, DiagonAlley, Hippogriff; also admin and recovery |
| `modules/profiles/secrets/sys.secrets.yaml` | devVM, DiagonAlley, Hippogriff; also admin and recovery |
| `modules/profiles/programs/mihomo/mihomo.secrets.yaml` | DiagonAlley, burrow, Hippogriff; also admin and recovery |
| `hosts/Willow/mihomo.secrets.yaml` | DiagonAlley, Willow's SSH host key; also admin and recovery |
| `hosts/KingsCross/netbird.secrets.yaml` | King'sCross SSH host key; also admin and recovery |
| `hosts/KingsCross/uni-next.secrets.yaml` | King'sCross SSH host key; also admin and recovery |
| `hosts/KingsCross/uni-next-api.secrets.yaml` | King'sCross SSH host key; also admin and recovery |

`users/seeker/ssh/github.secrets.json` is shared with all six listed machine
identities; the Android devices `mi15` and `miPad` are included. Public keys
use the `_unencrypted` suffix and are safe for Nix to read without decrypting a
private key.

## SSH keys

- `ssh/<host>.secrets.json` stores each host's outbound client key.
- `external.secrets.json` is the shared default key for external SSH;
  `github.secrets.json` is a separate key for GitHub.
- `admin.secrets.json` provides the administrator key to DiagonAlley, burrow,
  miLaptop, nixos-wsl, Hippogriff, mi15, and miPad.
- gpu01 receives the administrator public key and all five client public keys
  (DiagonAlley, miLaptop, devVM, nixos-wsl, Hippogriff) in `authorized_keys`.
  Home Manager atomically replaces a user-owned file, not a Nix-store symlink;
  OpenSSH `StrictModes` rejects the shared store ownership. Check for separately
  managed cluster keys before the first activation. gpu01 receives the shared
  external and GitHub private keys, not the administrator or mesh private key.

Register `public_key_unencrypted` from `github.secrets.json` with GitHub and
from `external.secrets.json` on external machines.

## AI credentials

`users/seeker/ai.secrets.json` contains only `claude_code_api_key` (the
allrouter.cc OMP `claude-code` provider) and `deepseek_official_api_key`
(`api.deepseek.com`). Edit it with `sops users/seeker/ai.secrets.json`.

When `programs.ai.enable` is set, Home Manager installs Codex and exports the
two keys through the `ai-env` template. With `programs.ai.omp.enable`, it also
installs OMP and writes `~/.omp/agent/models.yml` with only
`deepseek-official` and `claude-code`. The keyless development container
disables AI; burrow does not receive these credentials.

## Taskwarrior synchronization

`users/seeker/taskwarrior.secrets.yaml` contains the shared TaskChampion client
ID and client-side encryption secret. Home Manager renders them into a mode
`0400` configuration fragment on `miLaptop`, `DiagonAlley`, and `Hippogriff`.
King'sCross's sync server consumes only the client ID, but its SSH-host-key
identity can decrypt the same SOPS file, including the encryption secret.
`miLaptop` generates recurring tasks;
DiagonAlley and Hippogriff disable recurrence generation while retaining sync
and editing.

## Provisioning

Install the matching private identity before activating a configuration that
consumes SOPS secrets:

| Device | Source | Key-file path |
| --- | --- | --- |
| miLaptop | `.secrets/age/keys.txt` | `/persist/home/seeker/.config/sops/age/keys.txt` |
| nixos-wsl | `.secrets/age/keys.txt` | `~/.config/sops/age/keys.txt` |
| DiagonAlley | `.secrets/age/DiagonAlley.txt` | `/persist/home/seeker/.config/sops/age/keys.txt` |
| devVM | `.secrets/age/devVM.txt` | `/home/seeker/.config/sops/age/keys.txt` |
| Hippogriff | `.secrets/age/Hippogriff.txt` | `/home/seeker/.config/sops/age/keys.txt` |
| burrow | `.secrets/age/burrow.txt` | `/home/seeker/.config/sops/age/keys.txt` |
| gpu01 | `.secrets/age/gpu01.txt` | `/home/seeker4721/.config/sops/age/keys.txt` |
| mi15 / miPad | `.secrets/age/mi15.txt` / `.secrets/age/miPad.txt` | `~/.config/sops/age/keys.txt` on each device |

Set the key-file owner to the configured user and mode `0600` (the key directory
must be `0700`). The miLaptop persistence mount exposes its key at the standard
XDG path after boot; early activation reads the backing path above. If an
existing miLaptop still uses `/persist/home/seeker/age/keys`, copy that identity
to the current path before activation.

Nix-on-Droid outputs are `nixOnDroidConfigurations.mi15` and `.miPad`; install
each key before its first `nix-on-droid switch`. These profiles use the
`seeker` username and manage outbound SSH only; Android owns the app UID and
there is no system OpenSSH daemon.

Willow needs no manual key installation: its initial `nixos-anywhere` install
must use `--copy-host-keys` to preserve the SSH host key that provides its age
identity. See `docs/maintenance/willow.md`. Keep King'sCross's SSH host key as
well; if either VPS host key changes, update its anchor in `.sops.yaml` and
re-encrypt affected files with `sops updatekeys -y path/to/file.secrets.yaml`.
