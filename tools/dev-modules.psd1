# The PowerShell modules the checks use, pinned. Bump in a reviewed
# build(deps) commit; tools/Install-DevModules.ps1 saves exactly these into
# .modules/, and the other tools/ scripts import exactly these.
# Pester stays on 5.x: it still runs on Windows PowerShell 5.1, which is what
# end users run the script with.
@{
    Pester           = '5.9.1'
    PSScriptAnalyzer = '1.25.0'
}
