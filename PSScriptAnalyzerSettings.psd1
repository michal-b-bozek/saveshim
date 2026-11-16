# PSScriptAnalyzer rules for this repository (mise run lint).
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        # The script talks to the person running it, in colour; its messages
        # are not pipeline output.
        'PSAvoidUsingWriteHost'
    )
    Rules        = @{
        # The script must keep running in Windows PowerShell 5.1.
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
    }
}
