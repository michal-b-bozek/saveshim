# Dot-sourced by the other tools/ scripts: puts .modules/ first on the module
# path and imports a pinned module from it.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModuleDir = Join-Path $RepoRoot '.modules'
$DevModules = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'dev-modules.psd1')

function Import-DevModule {
    param([Parameter(Mandatory = $true)] [string] $Name)
    $version = $DevModules[$Name]
    $sep = [IO.Path]::PathSeparator
    if (-not (($env:PSModulePath -split $sep) -contains $ModuleDir)) {
        $env:PSModulePath = $ModuleDir + $sep + $env:PSModulePath
    }
    if (-not (Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq [version]$version })) {
        throw "$Name $version is not installed; run: mise run deps:install"
    }
    Import-Module -Name $Name -RequiredVersion $version -Force
}
