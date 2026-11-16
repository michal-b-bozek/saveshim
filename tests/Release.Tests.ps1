# Tests for the release tools in tools/ (Pester 5): the version line, the
# release zip and the release notes.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables set in BeforeAll are read in the It blocks.')]
param()

BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    $tools = Join-Path $repo 'tools'
}

Describe 'Set-Version.ps1' {
    BeforeEach {
        $copy = Join-Path $TestDrive 'Install-Saveshim.ps1'
        [IO.File]::WriteAllText($copy, "# a`r`n`$Version = '0.1.0'`r`n`$Other = 1`r`n")
    }

    It 'rewrites the $Version line and keeps the CRLF line endings' {
        & (Join-Path $tools 'Set-Version.ps1') -Version '1.2.3' -Path $copy | Out-Null
        [IO.File]::ReadAllText($copy) | Should -BeExactly "# a`r`n`$Version = '1.2.3'`r`n`$Other = 1`r`n"
    }

    It 'rejects <Version>' -ForEach @(@{ Version = '1.2' }, @{ Version = 'v1.2.3' }, @{ Version = '1.2.3-rc.1' }) {
        { & (Join-Path $tools 'Set-Version.ps1') -Version $Version -Path $copy } | Should -Throw '*not a plain X.Y.Z*'
    }

    It 'fails when the script has no single $Version line' {
        [IO.File]::WriteAllText($copy, "`$Version = '0.1.0'`n`$Version = '0.1.0'`n")
        { & (Join-Path $tools 'Set-Version.ps1') -Version '1.2.3' -Path $copy } | Should -Throw '*found 2*'
    }

    It 'finds the line in the real script' {
        $real = Join-Path $TestDrive 'real.ps1'
        Copy-Item -LiteralPath (Join-Path $repo 'Install-Saveshim.ps1') -Destination $real
        { & (Join-Path $tools 'Set-Version.ps1') -Version '9.9.9' -Path $real } | Should -Not -Throw
    }
}

Describe 'New-ReleaseZip.ps1' {
    BeforeAll {
        # A stand-in repository: the five release files and one that must stay out.
        $root = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $root | Out-Null
        foreach ($name in 'games.psd1', 'README.md', 'TROUBLESHOOTING.md', 'LICENSE', 'CONTRIBUTING.md') {
            Set-Content -LiteralPath (Join-Path $root $name) -Value $name
        }
        Set-Content -LiteralPath (Join-Path $root 'Install-Saveshim.ps1') -Value "`$Version = '4.5.6'"
        $zip = & (Join-Path $tools 'New-ReleaseZip.ps1') -Root $root -OutDir (Join-Path $TestDrive 'build')
    }

    It 'names the zip after the script''s version' {
        Split-Path -Leaf $zip | Should -BeExactly 'saveshim-4.5.6.zip'
    }

    It 'holds exactly the files end users need, at the top level' {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($zip)
        try { $names = @($archive.Entries | ForEach-Object { $_.FullName }) } finally { $archive.Dispose() }
        ($names | Sort-Object) | Should -BeExactly @('games.psd1', 'Install-Saveshim.ps1', 'LICENSE', 'README.md', 'TROUBLESHOOTING.md')
    }

    It 'writes a sha256sum-style checksum that matches the zip' {
        $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::ReadAllText("$zip.sha256") | Should -BeExactly "$hash  saveshim-4.5.6.zip`n"
    }
}

Describe 'Get-ReleaseNotes.ps1' {
    BeforeAll {
        $changelog = Join-Path $TestDrive 'CHANGELOG.md'
        [IO.File]::WriteAllText($changelog, @'
# Changelog

## [Unreleased]

- - -
## [0.2.0] - 2026-12-01

### Fixed

- Something.

## [0.1.0] - 2026-11-16

### Added

- Per-user saves.

- - -

[0.1.0]: https://example.com
'@)
    }

    It 'prints only the section of the given release' {
        $notes = & (Join-Path $tools 'Get-ReleaseNotes.ps1') -Version '0.1.0' -Path $changelog
        $notes | Should -BeExactly "### Added`n`n- Per-user saves."
    }

    It 'stops at the next release heading' {
        $notes = & (Join-Path $tools 'Get-ReleaseNotes.ps1') -Version '0.2.0' -Path $changelog
        $notes | Should -BeExactly "### Fixed`n`n- Something."
    }

    It 'fails for a release with no section' {
        { & (Join-Path $tools 'Get-ReleaseNotes.ps1') -Version '0.3.0' -Path $changelog } | Should -Throw '*no*section*'
    }
}
