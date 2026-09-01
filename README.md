# Isaac Repentance+ 1.9.7.17 CPU Fix

A small, version-locked patcher for the Repentance+ idle worker busy loop that
can consume a CPU thread even on the menu or while idle.

The repository contains patching code only. It does **not** contain or download
`isaac-ng.exe` or any other game asset.

## Supported build

- Repentance+ `1.9.7.17`, 32-bit `isaac-ng.exe`
- Original SHA-256:
  `3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b`
- Windows and Steam Deck/Proton

The injected code is position-independent, so Windows ASLR is supported.

## Use

Close the game first.

### Windows

```powershell
.\windows\isaac-cpu-fix.ps1 status
.\windows\isaac-cpu-fix.ps1 apply
.\windows\isaac-cpu-fix.ps1 revert
```

If Steam is installed in a non-default location, pass the executable explicitly:

```powershell
.\windows\isaac-cpu-fix.ps1 apply "D:\SteamLibrary\steamapps\common\The Binding of Isaac Rebirth\isaac-ng.exe"
```

### Steam Deck

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
- `revert` only operates when the executable exactly matches this patch.
- Steam updates or “Verify integrity of game files” may restore the original
  executable; run `status` after an update.

Do not use executable modifications for public or competitive online play.

See [technical notes](docs/technical-notes.md) for the root cause, patch layout,
and why a normal Lua/Workshop Mod cannot solve this engine-thread bug. See the
[verification record](docs/verification.md) for measured before/after results.
