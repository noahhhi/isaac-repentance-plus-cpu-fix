# Isaac CPU Fix & 1.9.7.15 Downgrade

A small, version-locked patcher for the Repentance+ idle worker busy loop that
can consume a CPU thread even on the menu or while idle.

Windows uses standalone **PowerShell 5.1+**, with no Python or extra modules.
The release contains scripts only. The downgrade command downloads official game
files through your signed-in Steam client; game files are never hosted here.

## Windows: curl one-liners / 一键命令

在 **PowerShell** 中执行，先退出游戏。使用 `curl.exe`，避免 Windows PowerShell
把 `curl` 当作 `Invoke-WebRequest`。下载失败不会运行脚本；下载路径每次唯一。
`ExecutionPolicy Bypass` 仅作用于这次脚本进程，不更改系统执行策略。

安装 CPU 修复补丁（仅支持下面列出的 1.9.7.17）：

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p install }
```

卸载 CPU 修复补丁（还原原版 EXE，不卸载游戏）：

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p uninstall }
```

降级到 **1.9.7.15.J374**（Steam 需已登录并拥有游戏和 Repentance+）：

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p downgrade }
```

补丁和降级是两个替代方案：1.9.7.15 无需安装这个 1.9.7.17 补丁。
降级会直接覆盖官方 depot 文件，保留额外文件、模组及存档，不备份存档。
它使用 `download_depot 250900 3353471 4926516310915821720`，等待本次下载完成、
验证旧版 EXE 后复制，并对所有复制文件做 SHA-256 校验。默认超时 30 分钟。
复制失败时可能已部分覆盖；修复权限/文件占用问题后重试。

**不会锁定 Steam 更新。** Steam 自动更新或验证完整性可能恢复最新版。
`uninstall` 只撤销 CPU 补丁，不撤销降级；恢复最新版请在 Steam 验证游戏完整性。
旧版在线联机与现有模组兼容性需自行确认。

脚本会从 Steam 注册表及 `libraryfolders.vdf` 找到游戏。存在多套安装时会要求指定路径。
可在命令末尾追加 `-IsaacExe 'D:\SteamLibrary\steamapps\common\The Binding of Isaac Rebirth\isaac-ng.exe'`；
Steam 非默认位置可追加 `-SteamPath 'D:\Steam'`。
单独下载 `isaac-downgrade.ps1` 时需要同目录的 `isaac-cpu-fix.ps1`；发布 ZIP 已包含两者。

## Supported build

- Repentance+ `1.9.7.17`, 32-bit `isaac-ng.exe`
- Original SHA-256:
  `3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b`
- Windows and Steam Deck/Proton

The injected code is position-independent, so Windows ASLR is supported.

## Use

Close the game first.

### Windows

No Python required. The curl commands above need only the single downloaded script.

```powershell
.\windows\isaac-cpu-fix.ps1 status
.\windows\isaac-cpu-fix.ps1 apply
.\windows\isaac-cpu-fix.ps1 revert
.\windows\isaac-downgrade.ps1
```

If Steam is installed in a non-default location, pass the executable explicitly:

```powershell
.\windows\isaac-cpu-fix.ps1 apply "D:\SteamLibrary\steamapps\common\The Binding of Isaac Rebirth\isaac-ng.exe"
```

### Steam Deck

The existing Steam Deck shell launcher still uses Python 3. The new pure
PowerShell and automatic downgrade commands are for Windows.

From a terminal in the repository:

```bash
chmod +x steam-deck/isaac-cpu-fix.sh
./steam-deck/isaac-cpu-fix.sh status
./steam-deck/isaac-cpu-fix.sh apply
```

Revert with:

```bash
./steam-deck/isaac-cpu-fix.sh revert
```

## Safety behavior

- Refuses unsupported hashes and unexpected machine code.
- Creates a timestamp-independent, hash-named backup before the first change.
- Writes atomically and verifies the patched bytes afterward.
- Windows `revert` verifies that restoring the patch produces the exact original
  SHA-256, rejecting unrelated modifications anywhere in the executable.
- Steam updates or “Verify integrity of game files” may restore the original
  executable; run `status` after an update.

Do not use executable modifications for public or competitive online play.

See [technical notes](docs/technical-notes.md) for the root cause, patch layout,
and why a normal Lua/Workshop Mod cannot solve this engine-thread bug. See the
[verification record](docs/verification.md) for measured before/after results.
