# Writes a release version into Install-Saveshim.ps1's $Version line.
# cog bump runs it through `mise run version:set <version>` (cog.toml), which
# also stages the file so the version commit carries it.
param(
    [Parameter(Mandatory = $true)] [string] $Version,
    # The script to change; the tests point it at a copy.
    [string] $Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Install-Saveshim.ps1')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "'$Version' is not a plain X.Y.Z version"
}
$text = [IO.File]::ReadAllText($Path)
$pattern = "(?m)^\`$Version = '[^']*'"
$count = [regex]::Matches($text, $pattern).Count
if ($count -ne 1) {
    throw "Expected one `$Version line in $Path, found $count"
}
# Only the quoted value changes, so the line endings stay as they are.
$text = [regex]::Replace($text, $pattern, "`$Version = '$Version'")
[IO.File]::WriteAllText($Path, $text)
Write-Output "Install-Saveshim.ps1 is now version $Version"
