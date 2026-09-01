param(
    [ValidateSet('status', 'apply', 'revert')]
    [string]$Command = 'status',
    [string]$IsaacExe = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$patcher = Join-Path $repoRoot 'patcher.py'
$python = Get-Command python -ErrorAction Stop
$arguments = @($patcher, $Command)
if ($IsaacExe) {
    $arguments += $IsaacExe
}
& $python.Source @arguments
exit $LASTEXITCODE
