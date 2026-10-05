#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position=0)][ValidateSet('status','apply','install','revert','uninstall','downgrade')][string]$Command='status',
    [Parameter(Position=1)][string]$IsaacExe='',
    [string]$SteamPath='',
    [ValidateRange(30,86400)][int]$TimeoutSeconds=1800
)
$ErrorActionPreference='Stop'
$script:OriginalHash='3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b'
$script:OldHash='f1c4a0e7448b8a05b653dd4535614a368fe0fcb24394cce3d4d587f10fd2c888'
$script:OriginalBranch=[byte[]](0xe9,0xd3,0,0,0)
$script:OriginalCave=[byte[]](@(0xcc)*20)
$script:PatchedBranch=[byte[]](0xe9,0x99,0x15,0,0)
$script:PatchedCave=[byte[]](0xe8,0,0,0,0,0x58,5,0x6f,0x83,7,0,0x6a,1,0xff,0x10,0xe9,0x26,0xeb,0xff,0xff)

function Get-BytesHash([byte[]]$Data) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Data))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-PatchOffsets([byte[]]$Data) {
    if ($Data.Length -lt 64 -or $Data[0] -ne 0x4d -or $Data[1] -ne 0x5a) { throw 'Invalid MZ header.' }
    $pe=[long][BitConverter]::ToUInt32($Data,60)
    if ($pe+24 -gt $Data.Length -or [BitConverter]::ToUInt32($Data,[int]$pe) -ne 0x4550) { throw 'Invalid PE header.' }
    if ([BitConverter]::ToUInt16($Data,[int]$pe+4) -ne 0x14c) { throw 'Expected x86 PE.' }
    $count=[BitConverter]::ToUInt16($Data,[int]$pe+6)
    $optSize=[BitConverter]::ToUInt16($Data,[int]$pe+20)
    $opt=$pe+24
    if ($optSize -lt 32 -or $opt+$optSize+40*$count -gt $Data.Length) { throw 'Truncated PE header.' }
    if ([BitConverter]::ToUInt16($Data,[int]$opt) -ne 0x10b) { throw 'Expected PE32.' }
    $base=[long][BitConverter]::ToUInt32($Data,[int]$opt+28)
    foreach ($target in @(@(0xa9e9c6,5),@(0xa9ff64,20))) {
        $rva=[long]$target[0]-$base
        $found=$false
        for ($i=0; $i -lt $count; $i++) {
            $s=[int]($opt+$optSize+40*$i)
            $start=[long][BitConverter]::ToUInt32($Data,$s+12)
            $size=[long][BitConverter]::ToUInt32($Data,$s+16)
            $raw=[long][BitConverter]::ToUInt32($Data,$s+20)
            if ($rva -ge $start -and $rva+$target[1] -le $start+$size) {
                $offset=$raw+$rva-$start
                if ($offset -lt 0 -or $offset+$target[1] -gt $Data.Length) { throw 'Invalid section bounds.' }
                [int]$offset
                $found=$true
                break
            }
        }
        if (-not $found) { throw 'Patch address is not backed by file data.' }
    }
}
function Test-Bytes([byte[]]$Data,[int]$Offset,[byte[]]$Expected) {
    for ($i=0; $i -lt $Expected.Length; $i++) { if ($Data[$Offset+$i] -ne $Expected[$i]) { return $false } }
    return $true
}
function Get-PatchState([byte[]]$Data) {
    $hash=Get-BytesHash $Data
    if ($hash -eq $script:OldHash) { return '1.9.7.15 (no CPU patch needed)' }
    $o=@(Get-PatchOffsets $Data)
    if ($hash -eq $script:OriginalHash -and (Test-Bytes $Data $o[0] $script:OriginalBranch) -and (Test-Bytes $Data $o[1] $script:OriginalCave)) { return 'original' }
    if ((Test-Bytes $Data $o[0] $script:PatchedBranch) -and (Test-Bytes $Data $o[1] $script:PatchedCave)) {
        $restored=[byte[]]$Data.Clone()
        [Array]::Copy($script:OriginalBranch,0,$restored,$o[0],5)
        [Array]::Copy($script:OriginalCave,0,$restored,$o[1],20)
        if ((Get-BytesHash $restored) -eq $script:OriginalHash) { return 'patched' }
    }
    return 'unsupported'
}
function Find-Steam([string]$Explicit) {
    if ($Explicit) {
        $p=(Get-Item -LiteralPath $Explicit).FullName
        if (Test-Path -LiteralPath (Join-Path $p 'steam.exe')) { return $p }
        throw 'SteamPath must contain steam.exe.'
    }
    $candidates=@()
    if (Test-Path 'HKCU:\Software\Valve\Steam') { $candidates+=(Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath }
    if (${env:ProgramFiles(x86)}) { $candidates+=(Join-Path ${env:ProgramFiles(x86)} 'Steam') }
    foreach ($p in $candidates) { if ($p -and (Test-Path -LiteralPath (Join-Path $p 'steam.exe'))) { return (Get-Item -LiteralPath $p).FullName } }
    throw 'Steam not found. Pass -SteamPath.'
}
function Find-Isaac([string]$Explicit,[string]$SteamRoot) {
    if ($Explicit) { return (Get-Item -LiteralPath $Explicit).FullName }
    if ($env:ISAAC_EXE) { return (Get-Item -LiteralPath $env:ISAAC_EXE).FullName }
    if (Test-Path -LiteralPath (Join-Path (Get-Location).Path 'isaac-ng.exe')) { return (Join-Path (Get-Location).Path 'isaac-ng.exe') }
    if (-not $SteamRoot) { $SteamRoot=Find-Steam '' }
    $libraries=@($SteamRoot)
    $vdf=Join-Path $SteamRoot 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')) { $libraries+=$m.Groups[1].Value.Replace('\\','\') }
    }
    $candidates=@($libraries | Sort-Object -Unique | ForEach-Object {
        $p=Join-Path $_ 'steamapps\common\The Binding of Isaac Rebirth\isaac-ng.exe'
        if ((Test-Path -LiteralPath (Join-Path $_ 'steamapps\appmanifest_250900.acf')) -and (Test-Path -LiteralPath $p)) { $p }
    })
    if ($candidates.Count -ne 1) { throw 'Could not identify one installed Isaac. Pass -IsaacExe.' }
    return $candidates[0]
}
function Assert-GameClosed {
    if (Get-Process -Name isaac-ng -ErrorAction SilentlyContinue) { throw 'Close Isaac before changing game files.' }
}
function Set-CpuPatch([string]$Path,[bool]$Apply) {
    Assert-GameClosed
    $data=[IO.File]::ReadAllBytes($Path)
    $state=Get-PatchState $data
    $wanted=if ($Apply) { 'patched' } else { 'original' }
    if ($state -eq $wanted) { return "Already $wanted" }
    if ($state -notin @('original','patched')) { throw "Unsupported executable: $state. Only exact 1.9.7.17 is patchable." }
    if ($Apply) {
        $backup=$Path+'.cpu-fix-backup-'+$script:OriginalHash.Substring(0,12)
        if (Test-Path -LiteralPath $backup) {
            if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $script:OriginalHash) { throw 'Existing backup has an unexpected hash.' }
        } else { [IO.File]::Copy($Path,$backup,$false) }
    }
    $o=@(Get-PatchOffsets $data)
    $branch=if ($Apply) { $script:PatchedBranch } else { $script:OriginalBranch }
    $cave=if ($Apply) { $script:PatchedCave } else { $script:OriginalCave }
    [Array]::Copy($branch,0,$data,$o[0],5)
    [Array]::Copy($cave,0,$data,$o[1],20)
    if ((Get-PatchState $data) -ne $wanted) { throw 'Pre-write verification failed.' }
    $temp=$Path+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllBytes($temp,$data)
        [IO.File]::Replace($temp,$Path,[System.Management.Automation.Language.NullString]::Value)
    } finally { if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) } }
    if ((Get-BytesHash ([IO.File]::ReadAllBytes($Path))) -ne (Get-BytesHash $data)) { throw 'Post-write verification failed.' }
    return "CPU patch: $wanted"
}
function Invoke-IsaacDowngrade([string]$Path,[string]$SteamRoot,[int]$Timeout) {
    Assert-GameClosed
    if (-not (Get-Process -Name steam -ErrorAction SilentlyContinue)) { throw 'Open Steam and sign in to the account that owns Isaac first.' }
    $manifest='4926516310915821720'
    $log=Join-Path $SteamRoot 'logs\console_log.txt'
    $offset=if (Test-Path -LiteralPath $log) { (Get-Item -LiteralPath $log).Length } else { 0 }
    Start-Process -FilePath (Join-Path $SteamRoot 'steam.exe') -ArgumentList '-console','+download_depot','250900','3353471',$manifest -WindowStyle Hidden
    Write-Host 'Downloading official 1.9.7.15 depot through Steam...'
    $deadline=[DateTime]::UtcNow.AddSeconds($Timeout)
    $text=''
    $depot=$null
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $log) {
            $stream=[IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
            try {
                if ($stream.Length -lt $offset) { throw 'Steam rotated its log. Retry the downgrade.' }
                [void]$stream.Seek($offset,[IO.SeekOrigin]::Begin)
                $reader=New-Object IO.StreamReader($stream)
                try { $text+=$reader.ReadToEnd(); $offset=$stream.Position } finally { $reader.Dispose() }
            } finally { $stream.Dispose() }
            $complete=[regex]::Match($text,'Depot download complete\s*:\s*"([^"]+)"\s*\(manifest '+$manifest+'\)')
            if ($complete.Success) { $depot=$complete.Groups[1].Value; break }
            if ($text -match '(?im)^.*(?:Depot download failed|Failed to download depot|Missing license|Access Denied).*$') { throw "Steam download failed: $($Matches[0])" }
        }
        Start-Sleep -Seconds 2
    }
    if (-not $depot) { throw 'Timed out waiting for Steam. Check its Console tab; installed files were not changed.' }
    $depot=(Get-Item -LiteralPath $depot).FullName.TrimEnd('\')
    $game=Split-Path -Parent $Path
    if ($depot -eq $game) { throw 'Download directory must differ from game directory.' }
    if ((Get-FileHash -LiteralPath (Join-Path $depot 'isaac-ng.exe') -Algorithm SHA256).Hash -ne $script:OldHash) { throw 'Downloaded EXE does not match 1.9.7.15.J374.' }
    Assert-GameClosed
    & robocopy.exe $depot $game /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NP
    if ($LASTEXITCODE -gt 7) { throw "Copy failed ($LASTEXITCODE). Some files may be replaced; resolve the error and rerun." }
    foreach ($file in Get-ChildItem -LiteralPath $depot -File -Recurse) {
        $relative=$file.FullName.Substring($depot.Length+1)
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $game $relative) -Algorithm SHA256).Hash) { throw "Verification failed: $relative" }
    }
    Write-Host 'Installed and verified 1.9.7.15.J374. Saves and mods preserved; no save backup made.'
    Write-Host 'Steam updates or Verify integrity can restore the newest version. Updates are not disabled.'
}
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $root=if ($SteamPath -or $Command -eq 'downgrade') { Find-Steam $SteamPath } else { '' }
        $path=Find-Isaac $IsaacExe $root
        switch ($Command) {
            { $_ -in 'apply','install' } { Set-CpuPatch $path $true }
            { $_ -in 'revert','uninstall' } { Set-CpuPatch $path $false }
            'downgrade' { Invoke-IsaacDowngrade $path $root $TimeoutSeconds }
            'status' { [pscustomobject]@{ Path=$path; State=Get-PatchState ([IO.File]::ReadAllBytes($path)); SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } }
        }
    } catch { Write-Error $_; exit 1 }
}
