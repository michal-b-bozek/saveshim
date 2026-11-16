<#
.SYNOPSIS
    Runs Install-Saveshim.ps1 for real: -WhatIf, install, re-run, uninstall.
    Each run starts a new Windows PowerShell with -File, as the README does,
    on a copy of the script next to a test games.psd1.

.DESCRIPTION
    CHANGES THE MACHINE: it installs a compatibility database for all users,
    creates C:\saveshim-smoke and a save folder in every user profile. Run it
    only on a disposable machine (CI runs it on a GitHub Windows runner), from
    an elevated Windows PowerShell, with -ThisMachineIsDisposable.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [switch] $ThisMachineIsDisposable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ThisMachineIsDisposable) { throw 'Run this only on a disposable machine; see the help.' }

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = 'C:\saveshim-smoke'
$script = Join-Path $root 'Install-Saveshim.ps1'
$sdb = Join-Path $root 'saveshim.sdb'
$installedKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\InstalledSDB\{6f0d3c52-8a1e-4c47-9b6a-2e5d7f4c1a90}'
$storeA = Join-Path $env:APPDATA 'saveshim-smoke\A'
$storeB = Join-Path $env:APPDATA 'saveshim-smoke\B'

function Assert-That([bool] $condition, [string] $message) {
    if (-not $condition) { throw "FAILED: $message" }
    Write-Output "ok: $message"
}

# Runs the copied script as the README does, with games.psd1 next to it.
function Invoke-Setup([string[]] $Arguments) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @Arguments
    if ($LASTEXITCODE -ne 0) { throw "FAILED: Install-Saveshim.ps1 $Arguments exited with $LASTEXITCODE" }
}

# Two games with the same exe name, as with GOG's ScummVM games, so the
# database has a combined entry; one of them uses RelativePaths. SmokeA lists
# a folder that doesn't exist first, as games.psd1 does for the two Program Files.
Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
foreach ($dir in "$root\GameA\Save", "$root\GameB\Saves") {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path (Split-Path -Parent $dir) 'smoke.exe') -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $repo 'Install-Saveshim.ps1') -Destination $script
$config = Join-Path $root 'games.psd1'
Set-Content -LiteralPath $config -Encoding ASCII -Value @"
@{
    Games = @(
        @{ Name = 'SmokeA'; Exe = 'smoke.exe'; SavePath = @('$root\Nowhere\Save', '$root\GameA\Save'); UserStore = '%USERAPPDATA%\saveshim-smoke\A' }
        @{ Name = 'SmokeB'; Exe = 'smoke.exe'; SavePath = '$root\GameB\Saves'; UserStore = '%USERAPPDATA%\saveshim-smoke\B'; RelativePaths = `$true }
    )
}
"@
Remove-Item -LiteralPath (Join-Path $env:APPDATA 'saveshim-smoke') -Recurse -Force -ErrorAction SilentlyContinue

Invoke-Setup '-WhatIf'
Assert-That (-not (Test-Path -LiteralPath $sdb)) '-WhatIf wrote no database'
Assert-That (-not (Test-Path -LiteralPath $storeA)) '-WhatIf created no save folder'
Assert-That (-not (Test-Path -LiteralPath $installedKey)) '-WhatIf installed nothing'

Invoke-Setup
Assert-That (Test-Path -LiteralPath $sdb) 'saveshim.sdb written'
Assert-That (Test-Path -LiteralPath $installedKey) 'database installed'
Assert-That ((Test-Path -LiteralPath $storeA) -and (Test-Path -LiteralPath $storeB)) 'save folders created'

Invoke-Setup
Assert-That (Test-Path -LiteralPath $installedKey) 're-run replaced the installed copy'

Invoke-Setup '-Uninstall'
Assert-That (-not (Test-Path -LiteralPath $installedKey)) 'uninstalled'
Assert-That (Test-Path -LiteralPath $storeA) 'save folders kept'

Invoke-Setup '-Uninstall'
Assert-That (-not (Test-Path -LiteralPath $installedKey)) 'a second -Uninstall is harmless'

Write-Output 'smoke test passed'
