# devVM Maintenance

`devVM` is the singleton development VM defined by
`nixosConfigurations.devVM`. The QEMU app keeps its disk at
`${XDG_STATE_HOME:-$HOME/.local/state}/dev-vm-qemu/devVM.qcow2` unless
`NIX_DISK_IMAGE` is set explicitly. Existing disks in the former
`dev-container-qemu` directory are reused automatically. Do not start two
instances against the same image.

## Build and Start

Run these commands from `/home/seeker/nixos-config`:

```bash
nix flake check --no-build --no-write-lock-file "path:$PWD"
nix build --no-link --no-write-lock-file \
  "path:$PWD#nixosConfigurations.devVM.config.system.build.toplevel"

# Creates the singleton qcow2 image on first use and reuses it afterwards.
# SSH is exposed only on the host loopback interface.
QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:2222-:22" \
  nix run --no-write-lock-file "path:$PWD#devVMQemu"
```

Stop QEMU cleanly before copying or backing up the qcow2 image. Removing that
image discards the VM state; rebuilding the app does not recreate its contents
in place.

## SOPS Bootstrap

The VM runtime identity is generated out of band at
`.secrets/age/devVM.txt`. Before expecting system or Home Manager secrets to
activate, install it inside the VM as:

```text
/home/seeker/.config/sops/age/keys.txt
```

The directory must be owned by `seeker` with mode `0700`; the key file must be
owned by `seeker` with mode `0600`. Transfer it over an already authenticated
channel or enter it from the VM console. Never add the identity file to Git or
the Nix store.

With the loopback port forwarding shown above, the administrator public key in
the declarative `authorized_keys` permits bootstrap before SOPS has deployed the
VM-specific private key:

```bash
ssh -p 2222 -i ~/.ssh/id_admin seeker@127.0.0.1 \
  'install -d -m 0700 ~/.config/sops/age'
scp -P 2222 -i ~/.ssh/id_admin .secrets/age/devVM.txt \
  seeker@127.0.0.1:.config/sops/age/keys.txt
ssh -p 2222 -i ~/.ssh/id_admin seeker@127.0.0.1 \
  'chmod 0600 ~/.config/sops/age/keys.txt'
```

After installing the key, restart the system and user secret units or reboot:

```bash
sudo systemctl restart sops-nix.service
systemctl --user restart sops-nix.service
```

The devVM identity can decrypt only its own SSH client key, the shared GitHub
key, and the system secrets consumed by devVM. It cannot decrypt
administrator, miLaptop, WSL, Mihomo, or King'sCross secrets.

## Update

Keep one working SSH or console session open while testing changes. From a
checkout inside devVM, build and activate temporarily before changing the boot
default:

```bash
sudo nixos-rebuild dry-build --no-write-lock-file --flake "path:$PWD#devVM"
sudo nixos-rebuild test --no-write-lock-file --flake "path:$PWD#devVM"

systemctl is-system-running --wait
systemctl is-active sshd sops-nix
systemctl --user is-active sops-nix
ssh -T git@github.com

sudo nixos-rebuild switch --no-write-lock-file --flake "path:$PWD#devVM"
```

`test` changes the running system but does not make it the boot default. If a
test breaks networking or SSH, reboot from the console to return to the last
switched generation. For an already switched generation, select an older entry
from GRUB or run `sudo nixos-rebuild switch --rollback` from the console.

## SSH Verification

The `seeker` account accepts the administrator public key and all three
development client public keys. After Home Manager decrypts the VM-specific
client key, outbound development SSH uses `~/.ssh/id_mesh`; other external SSH
uses `~/.ssh/id_external`; GitHub uses `~/.ssh/id_github`. The VM does not
receive `id_admin`.

Verify new connections rather than relying only on an existing control socket:

```bash
ssh -o ControlMaster=no -o ControlPath=none devVM hostname
ssh -o ControlMaster=no -o ControlPath=none ecos hostname
ssh -T git@github.com
```
