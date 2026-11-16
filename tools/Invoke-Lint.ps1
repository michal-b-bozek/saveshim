# Lints every PowerShell file with PSScriptAnalyzer and the rules in
# PSScriptAnalyzerSettings.psd1. Fails on any finding.
. (Join-Path $PSScriptRoot 'DevModules.ps1')
Import-DevModule -Name PSScriptAnalyzer

$settings = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'
$files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Include '*.ps1', '*.psd1' |
    Where-Object { $_.FullName -notlike (Join-Path $ModuleDir '*') }
$findings = @($files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $settings })
if ($findings.Count -gt 0) {
    $findings | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String -Width 200 | Write-Output
    throw "PSScriptAnalyzer: $($findings.Count) finding(s)"
}
Write-Output "PSScriptAnalyzer: $($files.Count) file(s), no findings"
