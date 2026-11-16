# Packs the files end users need into build/saveshim-<version>.zip, with a
# sha256sum-style checksum file next to it. The version is read from
# Install-Saveshim.ps1. The files sit at the top of the zip, so "Extract All"
# into C:\Tools\saveshim puts the script directly in that folder.
param(
    # The folder the files come from; the tests point it at a copy.
    [string] $Root = (Split-Path -Parent $PSScriptRoot),
    # Where the zip goes.
    [string] $OutDir = (Join-Path $Root 'build')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The files in a release; everything else in the repository is for development.
$ReleaseFiles = @('Install-Saveshim.ps1', 'games.psd1', 'README.md', 'TROUBLESHOOTING.md', 'LICENSE')

$match = [regex]::Match([IO.File]::ReadAllText((Join-Path $Root 'Install-Saveshim.ps1')), "(?m)^\`$Version = '(\d+\.\d+\.\d+)'")
if (-not $match.Success) { throw 'No $Version line in Install-Saveshim.ps1' }
$version = $match.Groups[1].Value

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$name = "saveshim-$version.zip"
$zip = Join-Path $OutDir $name
Remove-Item -LiteralPath $zip, "$zip.sha256" -ErrorAction SilentlyContinue
Compress-Archive -LiteralPath ($ReleaseFiles | ForEach-Object { Join-Path $Root $_ }) -DestinationPath $zip

$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
# Two spaces, as sha256sum writes it, so `sha256sum -c` can check it.
[IO.File]::WriteAllText("$zip.sha256", "$hash  $name`n")
Write-Output $zip
