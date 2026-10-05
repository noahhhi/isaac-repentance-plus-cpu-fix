#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory.' }
$out=New-Item -ItemType Directory -Path $OutputDirectory
Copy-Item -LiteralPath (Join-Path $repo 'windows\isaac-cpu-fix.ps1') -Destination $out.FullName
Copy-Item -LiteralPath (Join-Path $repo 'windows\isaac-downgrade.ps1') -Destination $out.FullName
Compress-Archive -LiteralPath (Join-Path $out.FullName 'isaac-cpu-fix.ps1'),(Join-Path $out.FullName 'isaac-downgrade.ps1') -DestinationPath (Join-Path $out.FullName 'isaac-windows-v0.2.0.zip')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'steam-deck') -Filter '*.sh') {
    # Git checkouts on Windows may have CRLF; release Bash files always use LF.
    $text=[IO.File]::ReadAllText($file.FullName).Replace("`r`n","`n")
    [IO.File]::WriteAllText((Join-Path $out.FullName $file.Name),$text,(New-Object Text.UTF8Encoding($false)))
}
$lines=@(Get-ChildItem -LiteralPath $out.FullName -File | Sort-Object Name | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$_.Name
})
[IO.File]::WriteAllLines((Join-Path $out.FullName 'SHA256SUMS.txt'),$lines,(New-Object Text.UTF8Encoding($false)))
Get-ChildItem -LiteralPath $out.FullName | Select-Object Name,Length
