# Linux / Steam Deck

The standalone Bash script requires Bash and standard GNU utilities (coreutils, sed, grep, find and procps). It does not require Python, sudo, or disabling SteamOS read-only protection. The target is the Windows `isaac-ng.exe` run through Proton, not the native Linux executable. Close Isaac first and use Steam Deck Desktop Mode / Konsole.

Install the 1.9.7.17 CPU patch:

```bash
p=$(mktemp) && curl -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.sh -o "$p" && bash "$p" install
```

Uninstall the CPU patch:

```bash
p=$(mktemp) && curl -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.sh -o "$p" && bash "$p" uninstall
```

Downgrade to 1.9.7.15.J374:

```bash
p=$(mktemp) && curl -fL --retry 3 https://github.com/noahhhi/isaac-repentance-plus-cpu-fix/releases/download/v0.2.0/isaac-cpu-fix.sh -o "$p" && bash "$p" downgrade
```

The downgrade requires the Steam desktop client already running and signed in to an account with access to the depot. It requests official app `250900`, depot `3353471`, manifest `4926516310915821720`, waits for a fresh download-complete log entry, checks the old EXE SHA-256, copies the depot over the installation and verifies every copied file. It does not back up saves, delete extra installation files, disable Steam updates, or change Proton settings. Steam's Verify integrity or subsequent updates may restore the newest version. `uninstall` removes the CPU patch; it does not undo a downgrade. Use Steam Verify integrity to return to the current official version.

Auto-detection covers the standard Steam/Steam Deck paths, Flatpak Steam data and additional libraries in `libraryfolders.vdf`. For an explicit path:

```bash
bash "$p" status '/run/media/deck/My SD/steamapps/common/The Binding of Isaac Rebirth/isaac-ng.exe'
```

`ISAAC_EXE` overrides executable detection; `STEAM_ROOT` selects the Steam client data directory. `DOWNLOAD_TIMEOUT=3600` increases the default 1800-second download timeout. The script refuses to patch an unknown executable, even when the patch-site bytes match: originals require the full known SHA-256; patched files must restore to that same hash before they are recognized. An EXE backup is created when installing the patch.

Validation: `bash -n steam-deck/isaac-cpu-fix.sh` and `bash tests/test-linux.sh`. The test optionally accepts an original 1.9.7.17 EXE path and tests only a temporary copy. Synthetic PE fixtures test round trips, idempotence and tamper rejection; mocked Steam completion tests downgrade copying and mod preservation.

On 2026-10-05 the script was also tested on a physical Steam Deck via SSH: automatic version detection, running-game refusal, and an original EXE temporary-copy apply/revert cycle passed. The real signed-in Steam client completed the requested old depot download; its files were copied to a temporary target and every file hash verified. The temporary-target test bypassed only the running-game guard because the installed game was in use. No installed game files or saves were modified. Gameplay/performance was not retested. This found and fixed Linux Steam logging a depot path with backslash separators.
