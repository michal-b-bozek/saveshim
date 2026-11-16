# Prints one release's section of CHANGELOG.md, for the GitHub release notes.
# Fails if the section is missing or has no entries, so a release is never
# published with empty notes.
param(
    [Parameter(Mandatory = $true)] [string] $Version,
    # The changelog to read; the tests point it at a copy.
    [string] $Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'CHANGELOG.md')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "'$Version' is not a plain X.Y.Z version"
}
$heading = "## [$Version]"
$lines = [IO.File]::ReadAllLines($Path)
$section = New-Object System.Collections.Generic.List[string]
$inside = $false
foreach ($line in $lines) {
    if (-not $inside) {
        # "## [0.1.0] - 2026-11-16" or a bare "## [0.1.0]".
        if ($line -eq $heading -or $line.StartsWith("$heading - ")) { $inside = $true }
        continue
    }
    # The section ends at the next release, cocogitto's separator or the links.
    if ($line -match '^## ' -or $line -match '^- - -\s*$' -or $line -match '^\[[^\]]+\]: ') { break }
    $section.Add($line)
}
$text = ($section -join "`n").Trim()
if (-not ($section | Where-Object { $_ -match '\S' -and $_ -notmatch '^#' })) {
    throw "CHANGELOG.md has no '$heading - date' section with entries"
}
Write-Output $text
