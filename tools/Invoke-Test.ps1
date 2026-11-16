# Runs the Pester tests in tests/. Fails if any test fails.
param(
    # Also write NUnit XML results to this path (CI uploads them).
    [string] $ResultPath
)
. (Join-Path $PSScriptRoot 'DevModules.ps1')
Import-DevModule -Name Pester

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $RepoRoot 'tests'
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
if ($ResultPath) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = $ResultPath
}
Invoke-Pester -Configuration $config
