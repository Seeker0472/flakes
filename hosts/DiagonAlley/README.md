# DiagonAlley 安装注意事项

安装流程见 `docs/installation.md`；磁盘定义以 `hosts/DiagonAlley/disk.nix`
为准。当前配置目标：

```text
/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NU0W123827
```

每次运行 Disko 前都必须核对稳定路径和实际设备：

```bash
target=/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NU0W123827
readlink -f "$target"
lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN "$target"
```

`destroy,format,mount` 会清除目标盘上的全部数据。先完成备份，并确认
`readlink` 和 `lsblk` 显示的是预期物理盘；不要用易变的 `/dev/nvme*` 路径
代替稳定 by-id 路径。任何信息不符都不要继续。

首次安装前，把专用身份 `.secrets/age/DiagonAlley.txt` 放到
`/mnt/persist/home/seeker/.config/sops/age/keys.txt`。身份文件不得提交到 Git；
引导细节见 `SECRETS.md`。

当前 `resumeDevice` 和 `resumeOffset` 均为 `null`。不要照抄静态 swapfile
offset；先在本机验证休眠，再决定是否需要修改配置。TPM2 enrollment 流程见
`docs/installation.md`。
