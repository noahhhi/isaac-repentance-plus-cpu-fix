<h1 align="center">Isaac CPU Fix & Downgrade</h1>

<p align="center"><strong>Standalone PowerShell and Bash tools for the Repentance+ CPU busy-loop fix and downgrade to 1.9.7.15. No Python required.</strong></p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.zh-CN.md">简体中文</a>
</p>

## Recommended version

**Downgrading to 1.9.7.15.J374 is recommended.** This patch only fixes the CPU busy loop in the supported newer build, **1.9.7.17**. This version still has other performance problems, and Brimstone can automatically stop charging when using a controller. **Neither issue is fixed by this patch.** Installing it is not a complete performance or controller fix. Version 1.9.7.15 does not need this CPU patch.

## Windows

Close the game and run these commands in **PowerShell**. Windows PowerShell 5.1 and PowerShell 7 are supported.

**Administrator privileges are normally not required.** Use a regular PowerShell window first. You can also use Windows Terminal, but select a **PowerShell** tab, not Command Prompt (cmd) or WSL, for the Windows commands below. Windows Terminal itself does not imply administrator privileges.

Installing/uninstalling the patch and downgrading require write access to the game directory. If the script reports **Access denied** or **UnauthorizedAccessException** when writing there, close the game, right-click PowerShell or Windows Terminal, choose **Run as administrator**, open a PowerShell tab and retry the same command. A C: or D: installation alone does not determine whether elevation is needed; the folder permissions do. For downgrade, keep Steam running and signed in to your usual account. Do not switch to a different Windows user, as that can change Steam/account detection. The script does not elevate itself automatically.

### Downgrade to 1.9.7.15 (recommended)

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/windows/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p downgrade }
```

### Install the CPU patch (1.9.7.17 only)

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/windows/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p install }
```

### Uninstall the CPU patch

```powershell
$p=Join-Path $env:TEMP ('isaac-'+[guid]::NewGuid()+'.ps1'); curl.exe -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/windows/isaac-cpu-fix.ps1 -o $p; if ($LASTEXITCODE -eq 0) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p uninstall }
```

The script reads Steam’s registered location and `libraryfolders.vdf` to find the game across its libraries, even when Steam and Isaac are on different drives. Replace the final action with `status` to inspect the detected path before making changes.

If automatic detection fails or finds multiple installations, use Steam → Isaac → Manage → Browse local files to locate `isaac-ng.exe`. Append `-IsaacExe` followed by that file’s full path in quotes, inside the command’s final braces. Only use `-SteamPath` if Steam itself cannot be detected; it must point to the directory containing `steam.exe`, not the game library. `-TimeoutSeconds 3600` optionally extends the download timeout.

Failed downloads are not executed. `ExecutionPolicy Bypass` applies only to this process. Running `isaac-downgrade.ps1` directly requires `isaac-cpu-fix.ps1` beside it in the `windows` directory. The curl commands above need only one file.

## Linux / Steam Deck

Close the game and run these commands in Bash; on Steam Deck, use Desktop Mode and Konsole. The target is the **Windows `isaac-ng.exe` used by Proton**. 

### Downgrade to 1.9.7.15 (recommended)

```bash
p=$(mktemp) && curl -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/steam-deck/isaac-cpu-fix.sh -o "$p" && bash "$p" downgrade
```

### Install the CPU patch (1.9.7.17 only)

```bash
p=$(mktemp) && curl -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/steam-deck/isaac-cpu-fix.sh -o "$p" && bash "$p" install
```

### Uninstall the CPU patch

```bash
p=$(mktemp) && curl -fL --retry 3 https://raw.githubusercontent.com/noahhhi/isaac-repentance-plus-cpu-fix/main/steam-deck/isaac-cpu-fix.sh -o "$p" && bash "$p" uninstall
```

Supports default Steam paths, Flatpak and additional libraries. Replace the final action with `status`, or append the full EXE path after the action. `ISAAC_EXE` selects the game, `STEAM_ROOT` selects the Steam data directory, and `DOWNLOAD_TIMEOUT=3600` allows a one-hour download timeout.

## Usage notes

- For downgrade, keep Steam running and signed in to an account that owns Isaac and Repentance+. The script downloads official depot `3353471`, manifest `4926516310915821720`, then copies and verifies the files. No game assets are hosted in this repository.
- Downgrade directly overwrites depot files, preserves saves/mods/extra files, and does not back up saves. The default download timeout is 30 minutes. A copy failure can leave a partial downgrade; resolve the error and rerun.
- `uninstall` restores the CPU-patched EXE; it does not uninstall the game or undo a downgrade. To return to the current official build, use Steam’s **Verify integrity of game files**.
- Steam updates are not disabled. Updates or integrity verification may replace the patch or old version. Online and mod compatibility on the older version are not guaranteed.
- The CPU patch accepts only the known 1.9.7.17 original SHA-256, backs up the EXE and replaces it atomically. Uninstall verifies the full restored hash. Original SHA-256: `3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b`.

## Verification and downloads

Tested with Windows PowerShell 5.1/7, WSL Ubuntu and a physical Steam Deck. Real EXE temporary copies passed install/uninstall hash verification. The Deck’s Steam download and temporary-target downgrade passed all-file verification. These tests did not change installed games or saves, and did not retest gameplay performance.

The commands download the current scripts directly from this repository. For manual installation, download the [repository ZIP](https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/archive/refs/heads/main.zip) and use its `windows` or `steam-deck` directory. See [technical notes](docs/technical-notes.md) and [verification details](docs/verification.md).
