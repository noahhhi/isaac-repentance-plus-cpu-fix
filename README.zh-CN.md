<h1 align="center">Isaac CPU Fix & Downgrade</h1>

<p align="center"><strong>用于《以撒的结合：忏悔+》CPU 死循环修复和降级至 1.9.7.15 的独立 PowerShell / Bash 脚本，无需 Python。</strong></p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.zh-CN.md">简体中文</a>
</p>

## 推荐版本

**推荐降级到 1.9.7.15.J374。** 本补丁只修复所支持的新版本 **1.9.7.17** 的 CPU 死循环。实际游玩中该版本仍存在其他性能问题，而且使用手柄时，硫磺火会自动停止蓄力。**这些问题本补丁都没有修复。** 安装补丁不代表解决了全部性能或手柄问题；1.9.7.15 无需安装此 CPU 补丁。

## Windows

先退出游戏，在 **PowerShell** 中执行。支持 Windows PowerShell 5.1 和 PowerShell 7。使用 `curl.exe`，避免 PowerShell 的 `curl` 别名。

### 降级到 1.9.7.15（推荐）

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/windows/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p downgrade }
```

### 安装 CPU 补丁（仅限 1.9.7.17）

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/windows/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p install }
```

### 卸载 CPU 补丁

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/windows/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p uninstall }
```

**以上命令无需修改盘符或安装路径。** 脚本读取 Steam 注册位置及 `libraryfolders.vdf`，自动查找各游戏库；Steam 和以撒安装在不同盘也可以。可先把末尾操作改为 `status`，确认检测到的游戏路径。

只有自动检测失败或找到多套安装时，才需要在 Steam → 以撒 → 管理 → 浏览本地文件中找到 `isaac-ng.exe`，在命令最后的大括号内追加 `-IsaacExe` 和用引号包裹的实际完整路径。仅当 Steam 本身无法检测时才使用 `-SteamPath`；它应指向包含 `steam.exe` 的目录，而非游戏库。可选参数 `-TimeoutSeconds 3600` 将下载超时延长到一小时。

下载失败时不会执行脚本。`ExecutionPolicy Bypass` 仅影响本次进程，不修改系统执行策略。直接运行 `isaac-downgrade.ps1` 时，需要 `windows` 目录中同目录的 `isaac-cpu-fix.ps1`。以上 curl 命令只需下载一个文件。

## Linux / Steam Deck

先退出游戏，在 Bash 中执行；Steam Deck 请进入桌面模式并打开 Konsole。目标为 **Proton 使用的 Windows `isaac-ng.exe`**。需要 Bash 和常见 GNU 工具。

### 降级到 1.9.7.15（推荐）

```bash
p=$(mktemp) && curl -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/steam-deck/isaac-cpu-fix.sh -o "$p" && bash "$p" downgrade
```

### 安装 CPU 补丁（仅限 1.9.7.17）

```bash
p=$(mktemp) && curl -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/steam-deck/isaac-cpu-fix.sh -o "$p" && bash "$p" install
```

### 卸载 CPU 补丁

```bash
p=$(mktemp) && curl -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/steam-deck/isaac-cpu-fix.sh -o "$p" && bash "$p" uninstall
```

支持默认 Steam 目录、Flatpak 和额外游戏库。将末尾操作改为 `status` 可查看状态；操作后可追加完整 EXE 路径。环境变量 `ISAAC_EXE` 指定游戏，`STEAM_ROOT` 指定 Steam 数据目录，`DOWNLOAD_TIMEOUT=3600` 将超时改为一小时。

## 使用说明

- 降级时请保持 Steam 运行，并登录拥有以撒及 Repentance+ 的账号。脚本下载官方 depot `3353471`、manifest `4926516310915821720`，随后覆盖并校验文件。仓库不分发游戏资源。
- 降级直接覆盖 depot 文件，保留存档、模组及额外文件，不备份存档。默认下载超时为 30 分钟。复制失败可能造成部分覆盖，解决错误后重新执行即可。
- `uninstall` 还原打过 CPU 补丁的 EXE，不卸载游戏，也不撤销降级。恢复当前官方版本请使用 Steam 的**验证游戏文件完整性**。
- 脚本不禁用 Steam 更新。自动更新或完整性验证可能覆盖补丁或旧版本。旧版的在线联机和模组兼容性不作保证。
- CPU 补丁仅接受已知 1.9.7.17 原版 SHA-256，安装时备份 EXE 并原子替换，卸载时核对完整还原哈希。原版 SHA-256：`3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b`。

## 验证与下载

已在 Windows PowerShell 5.1/7、WSL Ubuntu 和 Steam Deck 真机验证。真实 EXE 临时副本安装/卸载后完整哈希一致；Deck 的 Steam 旧版下载、临时目录覆盖及逐文件校验通过。测试未改动已安装的游戏或存档，也未重新测试游戏性能。

以上命令直接下载仓库中的当前脚本。手动安装可下载[仓库 ZIP](https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/archive/refs/heads/main.zip)，使用其中的 `windows` 或 `steam-deck` 目录。另见[技术说明（英文）](docs/technical-notes.md)与[验证记录（英文）](docs/verification.md)。
