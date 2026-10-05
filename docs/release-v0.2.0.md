# v0.2.0：纯 PowerShell / Bash CPU 补丁 + 1.9.7.15 降级

Windows 无需 Python，支持内置 Windows PowerShell 5.1 和 PowerShell 7。
退出游戏后，在 PowerShell 粘贴下面任一命令。

## 一键安装 CPU 补丁

仅适用于已知 SHA-256 的 Repentance+ 1.9.7.17。自动定位 Steam 游戏，备份原 EXE，原子替换并校验。

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p install }
```

## 一键卸载 CPU 补丁

还原原始 EXE，不卸载游戏。兼容 v0.1.0 安装的同一补丁，完整哈希校验防止误改其他版本。

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p uninstall }
```

## 一键降级到 1.9.7.15.J374

Steam 需保持登录并拥有游戏及 Repentance+。通过官方 Steam 下载 depot `3353471`、manifest `4926516310915821720`，确认本次下载完成后直接覆盖并逐文件校验。保留存档和模组，不备份存档，默认超时 30 分钟。

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p downgrade }
```

1.9.7.15 不需要再装此 CPU 补丁。`uninstall` 不撤销降级；恢复最新版请在 Steam 验证游戏完整性。脚本不会禁用 Steam 更新，自动更新/完整性验证可能覆盖旧版。旧版在线联机和模组兼容性未作保证。

使用 `curl.exe` 而非 PowerShell 的 `curl` 别名；下载失败不会执行脚本。可将结尾操作改为 `status` 查看版本/哈希，或追加 `-IsaacExe '完整的 isaac-ng.exe 路径'`、`-SteamPath 'Steam目录'`。执行策略参数仅作用于本次进程。

附件含独立入口 `isaac-cpu-fix.ps1`，以及 ZIP 中配套的 `isaac-downgrade.ps1`。后者需要同目录的前者。`SHA256SUMS.txt` 提供附件校验值。

## Linux / Steam Deck：纯 Bash 一键命令

同样无需 Python。Steam Deck 桌面模式打开 Konsole，先关闭游戏；目标为通过 Proton 运行的 Windows EXE。无需 sudo，不修改 SteamOS 只读设置。

安装 CPU 补丁：

```bash
p=$(mktemp) && curl -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.sh -o "$p" && bash "$p" install
```

卸载 CPU 补丁：

```bash
p=$(mktemp) && curl -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.sh -o "$p" && bash "$p" uninstall
```

降级到 1.9.7.15.J374：

```bash
p=$(mktemp) && curl -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.sh -o "$p" && bash "$p" downgrade
```

单文件支持 `status`，可在操作后追加 EXE 路径。支持 `STEAM_ROOT`、`ISAAC_EXE` 和 `DOWNLOAD_TIMEOUT` 环境变量。Steam 更新行为、卸载与降级的区别同 Windows。详见 [Linux 文档](https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/blob/v0.2.0/docs/linux.md)。
