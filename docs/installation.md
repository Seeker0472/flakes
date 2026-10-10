# NixOS 安装

本流程用于 `miLaptop`、`DiagonAlley` 和 `burrow`。三台机器都由 Disko 清空
目标盘；磁盘路径和 SOPS 密钥必须按下表选择。

| 配置名 | 目标盘 | SOPS 密钥 | 目标路径 |
| --- | --- | --- | --- |
| `miLaptop` | `/dev/disk/by-id/nvme-SAMSUNG_MZVLB256HAHQ-000L7_S41GNA0K906073` | `.secrets/age/keys.txt` | `/mnt/persist/home/seeker/.config/sops/age/keys.txt` |
| `DiagonAlley` | `/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NU0W123827` | `.secrets/age/DiagonAlley.txt` | `/mnt/persist/home/seeker/.config/sops/age/keys.txt` |
| `burrow` | `/dev/disk/by-id/ata-SK_hynix_SC311_SATA_128GB_MJ86N833110606T20` | `.secrets/age/burrow.txt` | `/mnt/home/seeker/.config/sops/age/keys.txt` |

## 日常更新

安装完成后，日常更新推荐用 deploy-rs（各机器用法见 `docs/maintenance/`）：

```bash
nix run .#deploy-rs -- .#miLaptop
nix run .#deploy-rs -- .#kingsCross
nix run .#deploy-rs -- .#hippogriff
```

## 1. SCP 源码和密钥

从不含 `.secrets` 的干净 worktree 传输源码，只单独传输目标机器对应的
SOPS 密钥：

```bash
scp -r <WORKTREE> nixos@<LIVECD_IP>:/tmp/flakes
scp <SOPS_KEY> nixos@<LIVECD_IP>:/tmp/age-key
```

## 2. 检查磁盘标识并运行 Disko

在 LiveCD 中填入表中的 `HOST`、`DISK` 和 `KEY_TARGET`。`readlink` 的结果必须
与 `lsblk` 中准备清空的物理盘一致：

```bash
HOST='<FLAKE>'
DISK='<目标盘 by-id>'
KEY_TARGET='<密钥目标路径>'

readlink -f "$DISK"
lsblk -d -o NAME,SIZE,MODEL,SERIAL "$(readlink -f "$DISK")"

cd /tmp/flakes
sudo nix \
  --extra-experimental-features 'nix-command flakes' \
  --option substituters \
    'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option fallback true \
  run github:nix-community/disko/de5708739256238fb912c62f03988815db89ec9a -- \
  --mode destroy,format,mount \
  --flake "path:$PWD#$HOST"

sudo install -D -m 0600 -o 1000 -g 100 /tmp/age-key "$KEY_TARGET"
test ! -e /mnt/.swapvol/swapfile || sudo swapon /mnt/.swapvol/swapfile
```

## 3. 使用镜像站安装

```bash
sudo env GOPROXY=https://goproxy.cn,direct \
  nixos-install \
  --flake "path:$PWD#$HOST" \
  --no-write-lock-file \
  --no-channel-copy \
  --no-root-password \
  --option substituters \
    'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option fallback true
```

## 4. 为 LUKS2 注册 TPM2 自动解锁

此步骤只适用于 `miLaptop` 和 `DiagonAlley`，并且必须在安装完成、从目标盘首次
启动后分别在对应机器本地执行。不要在 LiveCD 中注册：enrollment 必须使用目标
机器自己的 TPM。共享 impermanence 模块已经启用 systemd initrd，并为 `crypted`
设置了 `tpm2-device=auto`，不需要再次修改 NixOS 配置或运行 Disko。

按主机名选择对应的稳定 LUKS 分区路径；未知主机不会继续：

```bash
case "$(hostname)" in
  miLaptop)
    LUKS_DEVICE=/dev/disk/by-id/nvme-SAMSUNG_MZVLB256HAHQ-000L7_S41GNA0K906073-part2
    ;;
  DiagonAlley)
    LUKS_DEVICE=/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NU0W123827-part2
    ;;
  *)
    echo "This host must not enroll a TPM2 key with this procedure." >&2
    exit 1
    ;;
esac
```

先确认路径指向该机器的 LUKS2 根分区，并检查 TPM2。将 LUKS header 备份到
外置存储；不要只把备份放在同一块加密磁盘上。

```bash
readlink -f "$LUKS_DEVICE"
lsblk -o NAME,PATH,TYPE,FSTYPE,SIZE,UUID "$LUKS_DEVICE"
sudo cryptsetup luksDump "$LUKS_DEVICE"
sudo systemd-analyze has-tpm2
sudo systemd-cryptenroll --tpm2-device=list

# 将路径替换为已挂载的外置存储，并按主机名区分备份文件。
sudo cryptsetup luksHeaderBackup "$LUKS_DEVICE" \
  --header-backup-file /mnt/external/HOST-luks2-header.img
```

确认 `luksDump` 显示 Version 2、TPM 列表中只有本机预期的 TPM 后，输入现有
LUKS 密码并新增 TPM2 keyslot：

```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  "$LUKS_DEVICE"
```

必须显式指定 `--tpm2-pcrs=7`；不要依赖 systemd 的默认值。此命令只新增 TPM2
凭据，不会删除原密码槽。保留原密码作为 TPM 清除、主板更换、PCR 变化或自动
解锁失败时的恢复方式，不要使用 `--wipe-slot=all`。

重启前创建一个不挂载的临时映射，确认仅靠 TPM2 就能解锁，然后立即关闭它：

```bash
sudo systemd-cryptsetup attach \
  tpm-test "$LUKS_DEVICE" - 'tpm2-device=auto,headless'
sudo cryptsetup status tpm-test
sudo systemd-cryptsetup detach tpm-test
```

测试成功后重启。若 TPM2 解锁失败，initrd 会回退到现有 LUKS 密码。启动后可
检查本次解锁日志；需要删除 TPM2 enrollment 时只清除 TPM2 槽：

```bash
sudo journalctl -b -u systemd-cryptsetup@crypted.service
sudo systemd-cryptenroll "$LUKS_DEVICE"

# 删除前先输入并确认现有 LUKS 密码仍可用。
sudo cryptsetup open --test-passphrase "$LUKS_DEVICE"
sudo systemd-cryptenroll --wipe-slot=tpm2 "$LUKS_DEVICE"
```

当前仓库没有配置 Secure Boot 或 Lanzaboote。PCR 7 只有在 Secure Boot 已正确
启用且信任密钥受控时，才能对启动链提供有意义的保护；Secure Boot 关闭时，
无交互 TPM2 解锁主要是便利功能，不能可靠防御能够从外部介质启动机器的攻击者。
在部署 Secure Boot 之前，如需更强的本地保护，可在 enrollment 时增加
`--tpm2-with-pin=yes`，代价是每次启动仍需输入 TPM PIN。启用 Secure Boot 或
修改其密钥后，先用保留的 LUKS 密码启动，再清除并重新注册 TPM2 槽。

参数和 TPM2/PCR 行为以
[systemd-cryptenroll(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html)
为准。

## King'sCross

`King'sCross` 只在首次安装或确定要清空 VPS 时使用 `nixos-anywhere`；日常更新
遵循 `docs/maintenance/kings-cross.md`。`--copy-host-keys` 保留现有 SSH host key，
使重装后的系统仍能解密 SOPS 文件：

```bash
cd /home/seeker/nixos-config
nix \
  --option substituters \
    'https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option fallback true \
  run github:nix-community/nixos-anywhere -- \
  --flake "path:$PWD#King'sCross" \
  --target-host root@vps.seekerer.com \
  -i /home/seeker/.ssh/id_admin \
  --copy-host-keys
```

## 其他 target

除注明的 PowerShell 命令外，以下命令均在仓库根目录执行：

```bash
# devVM：自动创建或复用 qcow2。
nix run --no-write-lock-file "path:$PWD#devVMQemu"

# nixos-wsl：在 Nix 环境中构建 tarball。
sudo nix run --no-write-lock-file \
  "path:$PWD#nixosConfigurations.nixos-wsl.config.system.build.tarballBuilder"

# 在包含 nixos.wsl 的目录中使用 PowerShell 导入。
wsl --install --from-file nixos.wsl --name NixOS

# 首次进入 nixos-wsl 后放置密钥并激活配置。
install -D -m 0600 .secrets/age/keys.txt ~/.config/sops/age/keys.txt
sudo nixos-rebuild switch --flake "path:$PWD#nixos-wsl"

# mi15 / miPad：先安装并启动 Nix-on-Droid 应用，再选择对应配置。
install -D -m 0600 .secrets/age/mi15.txt ~/.config/sops/age/keys.txt
nix-on-droid switch --flake "path:$PWD#mi15"

install -D -m 0600 .secrets/age/miPad.txt ~/.config/sops/age/keys.txt
nix-on-droid switch --flake "path:$PWD#miPad"

# gpu01：独立 Home Manager 配置。
install -D -m 0600 .secrets/age/gpu01.txt ~/.config/sops/age/keys.txt
nix run github:nix-community/home-manager -- \
  switch --flake "path:$PWD#seeker4721@gpu01"

# 开发容器镜像。
nix build --no-write-lock-file "path:$PWD#devContainerImage"
docker load < result
```
