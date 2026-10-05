#requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\windows\isaac-cpu-fix.ps1"
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Throws([scriptblock]$Action) {
    $threw=$false
    try { & $Action | Out-Null } catch { $threw=$true }
    Assert $threw 'Expected refusal.'
}
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('isaac-ps-test-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
try {
    # Synthetic PE: no copyrighted game files needed by CI.
    $data=New-Object byte[] 8704
    $data[0]=0x4d; $data[1]=0x5a
    [Array]::Copy([BitConverter]::GetBytes([int]128),0,$data,60,4)
    $data[128]=0x50; $data[129]=0x45
    [Array]::Copy([BitConverter]::GetBytes([uint16]0x14c),0,$data,132,2)
    $data[134]=1; $data[148]=224; $data[152]=0x0b; $data[153]=1
    [Array]::Copy([BitConverter]::GetBytes([int]0x400000),0,$data,180,4)
    [Array]::Copy([BitConverter]::GetBytes([int]0x69e000),0,$data,388,4)
    [Array]::Copy([BitConverter]::GetBytes([int]8192),0,$data,392,4)
    [Array]::Copy([BitConverter]::GetBytes([int]512),0,$data,396,4)
    $offsets=@(Get-PatchOffsets $data)
    Assert ($offsets[0] -eq 3014 -and $offsets[1] -eq 8548) 'PE mapping mismatch.'
    [Array]::Copy($script:OriginalBranch,0,$data,$offsets[0],5)
    [Array]::Copy($script:OriginalCave,0,$data,$offsets[1],20)
    Assert ((Get-PatchState $data) -eq 'unsupported') 'Unknown hash accepted.'
    # Only test scope trusts the generated fixture; production has no bypass.
    $script:OriginalHash=Get-BytesHash $data
    $target=Join-Path $testRoot 'isaac-ng.exe'
    [IO.File]::WriteAllBytes($target,$data)
    function Assert-GameClosed { }
    Set-CpuPatch $target $true
    $patched=[IO.File]::ReadAllBytes($target)
    Assert ((Get-PatchState $patched) -eq 'patched') 'Apply failed.'
    Assert ([BitConverter]::ToString($patched,$offsets[0],5) -eq 'E9-99-15-00-00') 'Branch mismatch.'
    Assert ([BitConverter]::ToString($patched,$offsets[1],20) -eq 'E8-00-00-00-00-58-05-6F-83-07-00-6A-01-FF-10-E9-26-EB-FF-FF') 'Cave mismatch.'
    Set-CpuPatch $target $true
    $patched[600]=99
    Assert ((Get-PatchState $patched) -eq 'unsupported') 'Tampered patch accepted.'
    [IO.File]::WriteAllBytes($target,$patched)
    Assert-Throws { Set-CpuPatch $target $false }
    $patched[600]=0
    [IO.File]::WriteAllBytes($target,$patched)
    Set-CpuPatch $target $false
    Set-CpuPatch $target $false
    Assert ((Get-FileHash $target).Hash -eq $script:OriginalHash) 'Revert did not restore full hash.'
    [IO.File]::WriteAllBytes(($target+'.cpu-fix-backup-'+$script:OriginalHash.Substring(0,12)),[byte[]](1,2))
    Assert-Throws { Set-CpuPatch $target $true }
    Assert-Throws { Get-PatchOffsets ([byte[]](1,2)) }
    $broken=[byte[]]$data.Clone(); $broken[392]=1; $broken[393]=0
    Assert-Throws { Get-PatchOffsets $broken }

    # Simulated Steam completion drives the real copy and all-file verification.
    $fakeSteam=Join-Path $testRoot 'Steam'
    $depot=Join-Path $fakeSteam 'depot'
    [void][IO.Directory]::CreateDirectory((Join-Path $fakeSteam 'logs'))
    [void][IO.Directory]::CreateDirectory($depot)
    $fakeGame=Join-Path $fakeSteam 'steamapps\common\The Binding of Isaac Rebirth'
    [void][IO.Directory]::CreateDirectory($fakeGame)
    [IO.File]::WriteAllText((Join-Path $fakeGame 'isaac-ng.exe'),'fixture')
    [IO.File]::WriteAllText((Join-Path $fakeSteam 'steamapps\appmanifest_250900.acf'),'fixture')
    [IO.File]::WriteAllText((Join-Path $fakeSteam 'steamapps\libraryfolders.vdf'),('"path" "'+$fakeSteam.ToUpperInvariant().Replace('\','\\')+'"'))
    Assert ((Find-Isaac '' $fakeSteam) -eq (Join-Path $fakeGame 'isaac-ng.exe')) 'Case-insensitive library deduplication failed.'
    [IO.File]::WriteAllBytes((Join-Path $depot 'isaac-ng.exe'),[byte[]](10,20,30))
    [IO.File]::WriteAllText((Join-Path $depot 'resource.txt'),'old resource')
    [IO.File]::WriteAllText((Join-Path $testRoot 'mod.txt'),'preserve')
    $script:OldHash=(Get-FileHash (Join-Path $depot 'isaac-ng.exe')).Hash
    function Get-Process { [pscustomobject]@{ ProcessName='steam' } }
    function Start-Process {
        [IO.File]::AppendAllText((Join-Path $fakeSteam 'logs\console_log.txt'),"Depot download complete : `"$depot`" (manifest 4926516310915821720)`n")
    }
    Invoke-IsaacDowngrade $target $fakeSteam 30
    Assert ((Get-FileHash $target).Hash -eq $script:OldHash) 'Downgrade copy failed.'
    Assert ([IO.File]::ReadAllText((Join-Path $testRoot 'mod.txt')) -eq 'preserve') 'Extra file lost.'
    $script:OldHash='wrong'
    Assert-Throws { Invoke-IsaacDowngrade $target $fakeSteam 30 }
    function Start-Process { [IO.File]::AppendAllText((Join-Path $fakeSteam 'logs\console_log.txt'),"Depot download failed : Missing license`n") }
    Assert-Throws { Invoke-IsaacDowngrade $target $fakeSteam 30 }
    Write-Host 'All PowerShell tests passed.'
} finally {
    # Delete only this test-created unique temporary directory.
    if ((Split-Path $testRoot -Leaf) -notlike 'isaac-ps-test-*') { throw 'Unexpected test cleanup path.' }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
