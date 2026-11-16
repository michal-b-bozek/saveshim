# Saves the pinned modules from tools/dev-modules.psd1 into .modules/.
# Needs PowerShell 7.4 or later (Save-PSResource); the saved modules also
# load in Windows PowerShell 5.1.
. (Join-Path $PSScriptRoot 'DevModules.ps1')

New-Item -ItemType Directory -Path $ModuleDir -Force | Out-Null
foreach ($name in $DevModules.Keys) {
    $version = $DevModules[$name]
    if (Test-Path -LiteralPath (Join-Path (Join-Path $ModuleDir $name) $version)) {
        Write-Output "$name $version already in .modules"
        continue
    }
    Save-PSResource -Name $name -Version $version -Repository PSGallery -TrustRepository -Path $ModuleDir
    Write-Output "$name $version saved to .modules"
}
