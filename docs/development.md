# Development

[mise](https://mise.jdx.dev/) pins the dev tools and runs every task; `mise tasks` lists them.
End users need none of it: they run `Install-Saveshim.ps1` in Windows PowerShell.

```sh
mise trust mise.toml      # once per clone
mise install              # pinned tools: pwsh, cocogitto, betterleaks, lefthook
mise run deps:install     # pinned PowerShell modules into .modules/
mise run hooks:install    # git hooks: secrets, commit messages, checks before push
mise run check            # every local quality gate
```

| Task            | What it runs                                                                       |
| --------------- | ---------------------------------------------------------------------------------- |
| `deps:install`  | `tools/Install-DevModules.ps1`: Pester and PSScriptAnalyzer, pinned in `tools/dev-modules.psd1` |
| `lint`          | `tools/Invoke-Lint.ps1`: PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1`, every finding fails |
| `test`          | `tools/Invoke-Test.ps1`: the Pester tests in `tests/`                               |
| `commits:check` | `cog check`: every commit is a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/) |
| `secrets:scan`  | betterleaks over the history and the working tree (`.betterleaks.toml`)            |
| `check`         | `lint`, `test`, `commits:check` and `secrets:scan`                                 |
| `pack`          | `tools/New-ReleaseZip.ps1`: `build/saveshim-<version>.zip` and its `.sha256`        |
| `version:set`   | `tools/Set-Version.ps1`: writes a version into the script's `$Version` line and stages it |
| `release:notes` | `tools/Get-ReleaseNotes.ps1`: prints a release's section of `CHANGELOG.md`          |

## Rules for the script

- **One file for end users.** Everything the setup does stays in `Install-Saveshim.ps1`
  ([ADR 6](architecture/decisions/0006-one-script.md)). Dot-sourcing it
  (`. .\Install-Saveshim.ps1`) defines the functions and returns before the main part, which is
  how the tests load it.
- **Windows PowerShell 5.1.** That's what end users run. Keep `Install-Saveshim.ps1` and
  `games.psd1` plain ASCII (5.1 reads a file without a byte order mark in the ANSI code page; a
  test checks it), and keep to syntax 5.1 parses (PSScriptAnalyzer's `PSUseCompatibleSyntax`).
- **CRLF.** `.gitattributes` gives `.ps1` and `.psd1` files CRLF line endings, also in the release
  zip and in GitHub's "Download ZIP".
- **Keep the database ID.** `$DatabaseId` must not change: it is how a run finds and replaces the
  copy installed before it.
- **No personal data** in tracked files or commit messages: no user names, machine paths beyond
  GOG Galaxy's install folders, or email addresses. Examples use `<user>`, `MyDynasty`,
  `C:\Tools\saveshim` and `D:\Games`.

## Tests

`tests/Install-Saveshim.Tests.ps1` holds unit tests for the logic that needs no administrator
rights: the `CorrectFilePaths` parameters and their quoting, the `games.psd1` checks, placeholder
expansion and grouping by exe name. They run on any OS with pwsh.

`tests/smoke/Invoke-SmokeTest.ps1` runs the script for real: `-WhatIf` changes nothing, the
database it writes installs, a re-run replaces it, and `-Uninstall` removes it and keeps the save
folders. It changes the machine, so it runs only in CI, on GitHub's disposable Windows runners,
or by hand on a throwaway VM with `-ThisMachineIsDisposable`.

CI (`.github/workflows/ci.yml`) runs three jobs: `mise run check` on Ubuntu; lint and tests on
Windows in both Windows PowerShell 5.1 and pwsh; and the smoke test in Windows PowerShell 5.1.

What only a real game on a real PC shows is in the [manual test protocol](testing.md).

## Releases

The version lives in one line of `Install-Saveshim.ps1` (`$Version`), which the script prints at
the start of every run and writes into the database. Commit types follow `cog.toml`;
`cog bump --auto` runs the checks, writes the new version into that line (`version:set`), and
makes the version commit and tag. The full release sequence is at the top of `cog.toml`.

A pushed `vX.Y.Z` tag runs `.github/workflows/release.yml`: it checks that the tag is on `main`
and matches `$Version`, runs CI, packs `saveshim-X.Y.Z.zip` with only the files end users need
(`mise run pack`), attests its build provenance, and leaves a draft release with the
`CHANGELOG.md` section as notes. Check the draft, then publish it by hand. A `vX.Y.Z-rc.N` tag
does the same as a draft pre-release, to try the flow first.
