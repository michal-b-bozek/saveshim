# Unit tests for the pure logic in Install-Saveshim.ps1 (Pester 5).
# Run with `mise run test`, or Invoke-Pester -Path tests. The script is
# dot-sourced: it defines its functions and returns before doing anything.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables set in BeforeAll are read in the It blocks.')]
param()

BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    . (Join-Path $repo 'Install-Saveshim.ps1')


    # Writes a games list to the test drive and returns its path.
    function Write-TestConfig {
        param([Parameter(Mandatory = $true)] [string] $Text)
        $path = Join-Path $TestDrive 'games.psd1'
        Set-Content -LiteralPath $path -Value $Text -Encoding ASCII
        return $path
    }

    # A game folder on the test drive: <root>\<Name>\Save and <Name>\<Exe>.
    function Initialize-TestGame {
        param([string] $Name = 'Game', [string] $Exe = 'game.exe')
        $dir = Join-Path $TestDrive $Name
        $save = Join-Path $dir 'Save'
        New-Item -ItemType Directory -Path $save -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir $Exe) -Force | Out-Null
        return $save
    }
}

Describe 'Get-FixPair' {
    It 'writes an absolute pair as "from;to"' {
        $game = @{ SavePath = 'C:\Games\Kyrandia\DAT\saves'; UserStore = '%USERAPPDATA%\ScummVM\Saved games\Kyrandia'; RelativePaths = $false }
        Get-FixPair -Game $game | Should -BeExactly '"C:\Games\Kyrandia\DAT\saves;%USERAPPDATA%\ScummVM\Saved games\Kyrandia"'
    }

    It 'drops trailing backslashes from both paths' {
        $game = @{ SavePath = 'C:\Games\X\Save\'; UserStore = '%USERPROFILE%\X\'; RelativePaths = $false }
        Get-FixPair -Game $game | Should -BeExactly '"C:\Games\X\Save;%USERPROFILE%\X"'
    }

    It 'writes a relative pair from the save folder name, ending in \\"' {
        $game = @{ SavePath = 'C:\Program Files (x86)\GOG Galaxy\Games\Pharaoh Gold\Save'; UserStore = '%USERAPPDATA%\Pharaoh\Saves'; RelativePaths = $true }
        Get-FixPair -Game $game | Should -BeExactly '"Save\;%USERAPPDATA%\Pharaoh\Saves\\"'
    }

    It 'never ends a relative pair in a single \" (an escaped quote)' {
        $game = @{ SavePath = 'D:\g\Save\'; UserStore = 'D:\saves\%USERNAME%\'; RelativePaths = $true }
        $pair = Get-FixPair -Game $game
        $pair | Should -Match '\\\\"$'
        $pair | Should -Not -Match '[^\\]\\"$'
    }

    It 'accepts forward slashes in a relative SavePath' {
        $game = @{ SavePath = 'D:/g/Save/'; UserStore = '%USERPROFILE%\S'; RelativePaths = $true }
        Get-FixPair -Game $game | Should -BeExactly '"Save\;%USERPROFILE%\S\\"'
    }
}

Describe 'Get-FixCommandLine' {
    It 'starts with -b and has one pair' {
        $game = @{ SavePath = 'C:\G\Save'; UserStore = '%USERPROFILE%\G'; RelativePaths = $false }
        Get-FixCommandLine -Games @($game) | Should -BeExactly '-b "C:\G\Save;%USERPROFILE%\G"'
    }

    It 'joins the pairs of several games with spaces, in order' {
        $a = @{ SavePath = 'C:\A\saves'; UserStore = '%USERAPPDATA%\ScummVM\Saved games\A'; RelativePaths = $false }
        $b = @{ SavePath = 'C:\B\Save'; UserStore = '%USERAPPDATA%\B'; RelativePaths = $true }
        Get-FixCommandLine -Games @($a, $b) |
            Should -BeExactly '-b "C:\A\saves;%USERAPPDATA%\ScummVM\Saved games\A" "Save\;%USERAPPDATA%\B\\"'
    }
}

Describe 'Get-ExeGroup' {
    It 'puts games with the same exe name, in any case, in one group' {
        $games = @(
            @{ Name = 'Pharaoh'; Exe = 'Pharaoh.exe' }
            @{ Name = 'Kyrandia'; Exe = 'scummvm.exe' }
            @{ Name = 'Kyrandia2'; Exe = 'ScummVM.EXE' }
        )
        $groups = @(Get-ExeGroup -Games $games)
        $groups.Count | Should -Be 2
        $scummvm = $groups | Where-Object { $_.Exe -eq 'scummvm.exe' }
        $scummvm.Names | Should -BeExactly 'Kyrandia, Kyrandia2'
        $scummvm.Games.Count | Should -Be 2
        ($groups | Where-Object { $_.Exe -eq 'Pharaoh.exe' }).Games.Count | Should -Be 1
    }
}

Describe 'Resolve-UserStore' {
    BeforeAll {
        $user1 = [pscustomobject]@{ ProfilePath = 'C:\Users\user1'; UserName = 'user1' }
    }

    It 'expands %USERAPPDATA% to the user''s Roaming folder' {
        Resolve-UserStore -Template '%USERAPPDATA%\Pharaoh\Saves' -UserProfile $user1 |
            Should -BeExactly 'C:\Users\user1\AppData\Roaming\Pharaoh\Saves'
    }

    It 'expands %USERPROFILE% and %USERNAME%' {
        Resolve-UserStore -Template '%USERPROFILE%\Saves' -UserProfile $user1 | Should -BeExactly 'C:\Users\user1\Saves'
        Resolve-UserStore -Template 'D:\savegames\%USERNAME%\Pharaoh' -UserProfile $user1 | Should -BeExactly 'D:\savegames\user1\Pharaoh'
    }

    It 'ignores the case of placeholders' {
        Resolve-UserStore -Template '%userappdata%\P' -UserProfile $user1 | Should -BeExactly 'C:\Users\user1\AppData\Roaming\P'
    }

    It 'drops trailing backslashes' {
        $p = [pscustomobject]@{ ProfilePath = 'C:\Users\user1\'; UserName = 'user1' }
        Resolve-UserStore -Template '%USERAPPDATA%\P\' -UserProfile $p | Should -BeExactly 'C:\Users\user1\AppData\Roaming\P'
    }

    It 'keeps a $ in a profile path or user name literally' {
        $p = [pscustomobject]@{ ProfilePath = 'C:\Users\svc$1'; UserName = 'a$&b$$' }
        Resolve-UserStore -Template '%USERAPPDATA%\P' -UserProfile $p | Should -BeExactly 'C:\Users\svc$1\AppData\Roaming\P'
        Resolve-UserStore -Template '%USERPROFILE%\P' -UserProfile $p | Should -BeExactly 'C:\Users\svc$1\P'
        Resolve-UserStore -Template 'D:\s\%USERNAME%' -UserProfile $p | Should -BeExactly 'D:\s\a$&b$$'
    }

    It 'keeps a $ in the template literally' {
        Resolve-UserStore -Template 'D:\saves$\%USERNAME%' -UserProfile $user1 | Should -BeExactly 'D:\saves$\user1'
    }
}

Describe 'Get-GameList' {
    It 'returns a valid game and defaults RelativePaths to $false' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\Game' } ) }"
        $games = @(Get-GameList -Path $path)
        $games.Count | Should -Be 1
        $games[0].Name | Should -BeExactly 'Game'
        $games[0].RelativePaths | Should -BeFalse
    }

    It 'keeps RelativePaths when set' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\Game'; RelativePaths = `$true } ) }"
        @(Get-GameList -Path $path)[0].RelativePaths | Should -BeTrue
    }

    It 'finds a ScummVM exe in a sibling folder without a warning' {
        $dir = Join-Path $TestDrive 'Kyrandia'
        $save = Join-Path (Join-Path $dir 'DAT') 'saves'
        New-Item -ItemType Directory -Path $save -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $dir 'scummvm') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path (Join-Path $dir 'scummvm') 'scummvm.exe') -Force | Out-Null
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Kyrandia'; Exe = 'scummvm.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\ScummVM\Saved games\Kyrandia' } ) }"
        $warnings = @(Get-GameList -Path $path 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 0
    }

    It 'warns, but accepts the game, when the exe is not near the save folder' {
        $save = Initialize-TestGame -Name 'Far' -Exe 'other.exe'
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Far'; Exe = 'far.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\Far' } ) }"
        $output = @(Get-GameList -Path $path 3>&1)
        $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -BeLike '*far.exe was not found*'
        @($output | Where-Object { $_ -is [hashtable] }).Count | Should -Be 1
    }

    It 'rejects a missing <Key>' -ForEach @(
        @{ Key = 'Name' }, @{ Key = 'Exe' }, @{ Key = 'SavePath' }, @{ Key = 'UserStore' }
    ) {
        $save = Initialize-TestGame
        $entry = @{ Name = "'Game'"; Exe = "'game.exe'"; SavePath = "'$save'"; UserStore = "'%USERAPPDATA%\Game'" }
        $entry.Remove($Key)
        $fields = ($entry.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join '; '
        $path = Write-TestConfig "@{ Games = @( @{ $fields } ) }"
        { Get-GameList -Path $path } | Should -Throw "*'$Key' is missing*"
    }

    It 'rejects a blank value' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = '  '; SavePath = '$save'; UserStore = '%USERAPPDATA%\Game' } ) }"
        { Get-GameList -Path $path 3>$null } | Should -Throw "*'Exe' is missing*"
    }

    It 'rejects a Name with spaces or punctuation' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Pharaoh Gold'; Exe = 'game.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\Game' } ) }"
        { Get-GameList -Path $path } | Should -Throw "*Name may contain only letters*"
    }

    It 'rejects a placeholder the fix does not expand' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = '$save'; UserStore = '%APPDATA%\Game' } ) }"
        { Get-GameList -Path $path } | Should -Throw "*UserStore uses %APPDATA%*"
    }

    It 'rejects a UserStore every user would share' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = '$save'; UserStore = 'D:\saves\Game' } ) }"
        { Get-GameList -Path $path } | Should -Throw "*every user would share it*"
    }

    It 'skips, with a warning, a game whose folder is not on this PC' {
        $save = Initialize-TestGame
        $missing = Join-Path (Join-Path $TestDrive 'Nowhere') 'Save'
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\Game' }; @{ Name = 'Gone'; Exe = 'gone.exe'; SavePath = '$missing'; UserStore = '%USERAPPDATA%\Gone' } ) }"
        $output = @(Get-GameList -Path $path 3>&1)
        $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -BeLike 'Gone: no game folder at *, so the game is skipped*'
        $games = @($output | Where-Object { $_ -is [hashtable] })
        $games.Count | Should -Be 1
        $games[0].Name | Should -BeExactly 'Game'
    }

    It 'uses the first SavePath in a list whose game folder exists' {
        $save = Initialize-TestGame
        $missing = Join-Path (Join-Path $TestDrive 'Nowhere') 'Save'
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = @('$missing', '$save'); UserStore = '%USERAPPDATA%\Game' } ) }"
        $output = @(Get-GameList -Path $path 3>&1)
        @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Count | Should -Be 0
        $games = @($output | Where-Object { $_ -is [hashtable] })
        $games[0].SavePath | Should -BeExactly $save
    }

    It 'names every folder it tried when no SavePath in a list is on this PC' {
        $save = Initialize-TestGame
        $a = Join-Path (Join-Path $TestDrive 'NowhereA') 'Save'
        $b = Join-Path (Join-Path $TestDrive 'NowhereB') 'Save'
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = '$save'; UserStore = '%USERAPPDATA%\Game' }; @{ Name = 'Gone'; Exe = 'gone.exe'; SavePath = @('$a', '$b'); UserStore = '%USERAPPDATA%\Gone' } ) }"
        $warnings = @(Get-GameList -Path $path 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -BeLike "*'$(Split-Path -Parent $a)' or '$(Split-Path -Parent $b)'*"
    }

    It 'rejects a blank path in a SavePath list' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Game'; Exe = 'game.exe'; SavePath = @('$save', ' '); UserStore = '%USERAPPDATA%\Game' } ) }"
        { Get-GameList -Path $path } | Should -Throw '*SavePath must be a path, or a list*'
    }

    It 'fails when none of the games is on this PC' {
        $missing = Join-Path (Join-Path $TestDrive 'Nowhere') 'Save'
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'Gone'; Exe = 'gone.exe'; SavePath = '$missing'; UserStore = '%USERAPPDATA%\Gone' } ) }"
        { Get-GameList -Path $path 3>$null } | Should -Throw '*None of the games*'
    }

    It 'rejects an empty or missing Games list: <Text>' -ForEach @(
        @{ Text = '@{ Games = @() }' }, @{ Text = '@{ }' }
    ) {
        $path = Write-TestConfig $Text
        { Get-GameList -Path $path } | Should -Throw '*Games is empty*'
    }

    It 'rejects an entry that is not @{ ... }' {
        $path = Write-TestConfig "@{ Games = @( 'Pharaoh' ) }"
        { Get-GameList -Path $path } | Should -Throw '*must be @{ ... }*'
    }

    It 'reports every problem at once' {
        $save = Initialize-TestGame
        $path = Write-TestConfig "@{ Games = @( @{ Name = 'A B'; Exe = 'game.exe'; SavePath = '$save'; UserStore = 'D:\shared' } ) }"
        $message = $null
        try { Get-GameList -Path $path } catch { $message = $_.Exception.Message }
        $message | Should -BeLike '*Name may contain only letters*'
        $message | Should -BeLike '*every user would share it*'
    }
}

Describe 'The shipped files' {
    It 'games.psd1 passes the checks' {
        $message = $null
        try { Get-GameList -Path (Join-Path $repo 'games.psd1') 3>$null | Out-Null } catch { $message = $_.Exception.Message }
        # On a PC without the games, the only complaint is that none was found.
        if ($message) { $message | Should -BeLike 'None of the games*' }
    }

    # Windows PowerShell 5.1 reads a script without a byte order mark in the
    # ANSI code page, so any non-ASCII character would come out garbled.
    It '<Name> is plain ASCII' -ForEach @(
        @{ Name = 'Install-Saveshim.ps1' }, @{ Name = 'games.psd1' }
    ) {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $repo $Name))
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }
}
