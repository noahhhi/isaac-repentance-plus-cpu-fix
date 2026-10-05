# Verification record

Tested on 2026-09-02 with:

- Windows 11
- AMD Ryzen 7 9800X3D (8 cores / 16 logical processors)
- Repentance+ 1.9.7.17
- Original executable SHA-256
  `3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b`

The unpatched process consumed 8.24% of the whole machine, equivalent to 1.32
fully occupied logical processors. One worker accumulated 3031.2 ms of CPU time
in a three-second sample.

After applying the patch on disk and launching a fresh process, Windows loaded
the image at `0x00480000` rather than its preferred base. The process remained
responsive and consumed 2.81% of the machine, equivalent to 0.45 logical
processors. No thread accumulated five seconds of CPU time in the five-second
sample. This verifies both the busy-loop reduction and ASLR-safe code path.

The patcher was also tested through a complete apply, status, revert, status,
apply, status cycle. Every transition passed byte-level and SHA-256 validation.

## Native script verification (2026-10-05)

- Windows PowerShell 5.1 and PowerShell 7: synthetic PE tests cover installation,
  idempotence, uninstall, full-file tamper rejection, invalid headers, backup
  validation, library path case handling and simulated Steam downgrade copying.
- A temporary copy of the real supported 1.9.7.17 EXE was patched and reverted
  with PowerShell, returning to the exact original SHA-256.
- Bash tests passed under WSL Ubuntu and on a physical Steam Deck; a real
  1.9.7.17 EXE temporary copy also completed the patch/revert hash round trip.
- On the Deck, the signed-in Steam client completed manifest 4926516310915821720.
  The Bash downgrade implementation copied it into a temporary game target and
  verified all file hashes. The running-game guard was overridden only for this
  isolated target; its refusal was separately checked against the running game.
- The Deck's installed EXE remained 1.9.7.15 throughout. No installed files or
  saves were modified. These are script/installation tests, not new performance
  measurements or gameplay compatibility tests.
