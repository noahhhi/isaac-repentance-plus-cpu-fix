#requires -Version 5.1
# Both scripts are included in the release ZIP. The curl one-liner uses
# isaac-cpu-fix.ps1 downgrade directly, with no companion file needed.
[CmdletBinding()]
param([string]$IsaacExe='', [string]$SteamPath='', [int]$TimeoutSeconds=1800)
$ErrorActionPreference='Stop'
$entry=Join-Path $PSScriptRoot 'isaac-cpu-fix.ps1'
if (-not (Test-Path -LiteralPath $entry)) { throw 'Place isaac-cpu-fix.ps1 beside this script, or use the single-file curl downgrade command.' }
& $entry downgrade -IsaacExe $IsaacExe -SteamPath $SteamPath -TimeoutSeconds $TimeoutSeconds
