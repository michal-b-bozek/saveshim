<#
.SYNOPSIS
    saveshim: give every Windows user their own saves for the games in
    games.psd1.

.DESCRIPTION
    Run once from an elevated PowerShell. It:

      1. checks games.psd1;
      2. writes a compatibility-fix database (saveshim.sdb, next to this
         script) that applies Windows' built-in CorrectFilePaths fix to each
         game's exe, redirecting its save folder to the user's own folder;
      3. creates the user's save folder for every account that has logged in
         at least once (the fix redirects but does not create folders);
      4. installs the database for all users with sdbinst, replacing an older
         copy installed by this script.

    Nothing has to be downloaded: the database is written with Windows' own
    apphelp.dll. Run it again after changing games.psd1 or adding a user.

    Use -WhatIf to see what it would do without changing anything.

.PARAMETER ConfigPath
    The games list. Defaults to games.psd1 next to this script.

.PARAMETER StoresOnly
    Only create the users' save folders (e.g. for a newly added user); leave
    the database alone.

.PARAMETER Uninstall
    Remove the installed database. Users' save folders are kept.

.EXAMPLE
    .\Install-Saveshim.ps1 -WhatIf

.EXAMPLE
    .\Install-Saveshim.ps1

.EXAMPLE
    .\Install-Saveshim.ps1 -Uninstall

.NOTES
    https://github.com/michal-b-bozek/saveshim
#>
[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [Parameter(ParameterSetName = 'StoresOnly')]
    # Empty means games.psd1 next to this script; see $ScriptDir below.
    [string] $ConfigPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'StoresOnly')]
    [switch] $StoresOnly,

    [Parameter(Mandatory = $true, ParameterSetName = 'Uninstall')]
    [switch] $Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This release. tools/Set-Version.ps1 rewrites this line when a release is cut.
$Version = '0.1.0'

# Fixed ID of the database this script writes, so a re-run replaces it.
$DatabaseId = [guid]'6f0d3c52-8a1e-4c47-9b6a-2e5d7f4c1a90'
$DatabaseName = 'saveshim: per-user game saves'
# The folder this script is in. Windows PowerShell 5.1 leaves $PSScriptRoot empty while
# it binds parameters of a script started with -File, as the README does, so the defaults
# that need the folder are set here, with a fallback to the script's own path.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $ScriptDir 'games.psd1' }
$SdbPath = Join-Path $ScriptDir 'saveshim.sdb'
$Sdbinst = "$env:SystemRoot\System32\sdbinst.exe"
$InstalledKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\InstalledSDB\{' + $DatabaseId + '}'

# Placeholders CorrectFilePaths itself expands (see its documentation).
$SupportedPlaceholders = @('%USERPROFILE%', '%USERNAME%', '%USERAPPDATA%')

function Write-Step {
    param([Parameter(Mandatory = $true)] [string] $Message)
    Write-Host ''
    Write-Host "== $Message" -ForegroundColor Cyan
}

function Assert-Admin {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this from an elevated PowerShell (right-click PowerShell, Run as administrator).'
    }
}

# --- configuration -------------------------------------------------------------

function Get-GameList {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $config = Import-PowerShellDataFile -LiteralPath $Path
    $problems = New-Object System.Collections.Generic.List[string]
    $games = @($config['Games'] | Where-Object { $null -ne $_ })
    if ($games.Count -eq 0) { $problems.Add('Games is empty') }
    # Games whose folder is not on this PC: skipped, so the shipped list of
    # GOG games works for someone who has only some of them.
    $missing = New-Object System.Collections.Generic.List[object]

    foreach ($game in $games) {
        if ($game -isnot [hashtable]) {
            $problems.Add("Each entry in Games must be @{ ... }; found '$game'")
            continue
        }
        $label = if ($game.ContainsKey('Name')) { $game.Name } else { '(no Name)' }
        foreach ($key in 'Name', 'Exe', 'SavePath', 'UserStore') {
            if (-not $game.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($game[$key])) {
                $problems.Add("$($label): '$key' is missing")
            }
        }
        # SavePath is one path, or a list of the places the game may be installed in.
        $savePaths = @()
        if ($game.ContainsKey('SavePath') -and -not [string]::IsNullOrWhiteSpace($game.SavePath)) {
            $savePaths = @($game.SavePath)
            if (@($savePaths | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
                $problems.Add("$($label): SavePath must be a path, or a list of paths with none of them blank")
                $savePaths = @()
            }
        }
        if (-not $game.ContainsKey('RelativePaths')) { $game.RelativePaths = $false }
        if ($game.ContainsKey('Name') -and $game.Name -notmatch '^[A-Za-z0-9_-]+$') {
            $problems.Add("$($label): Name may contain only letters, digits, '-' and '_'")
        }
        if ($game.ContainsKey('UserStore')) {
            foreach ($m in [regex]::Matches($game.UserStore, '%[^%]+%')) {
                if ($SupportedPlaceholders -notcontains $m.Value.ToUpperInvariant()) {
                    $problems.Add("$($label): UserStore uses $($m.Value); only $($SupportedPlaceholders -join ', ') are supported")
                }
            }
            if ($game.UserStore -notmatch '%USERPROFILE%|%USERNAME%|%USERAPPDATA%') {
                $problems.Add("$($label): UserStore has no per-user placeholder, so every user would share it")
            }
        }
        if ($savePaths.Count -gt 0 -and $game.ContainsKey('Exe')) {
            # The first SavePath whose game folder (the one above it) exists.
            $installDir = $null
            foreach ($candidate in $savePaths) {
                $dir = Split-Path -Parent $candidate.TrimEnd('\')
                if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) {
                    $game.SavePath = $candidate
                    $installDir = $dir
                    break
                }
            }
            if (-not $installDir) {
                $tried = ($savePaths | ForEach-Object { "'" + (Split-Path -Parent $_.TrimEnd('\')) + "'" }) -join ' or '
                Write-Warning "$($label): no game folder at $tried, so the game is skipped. Fine if it is not installed here; otherwise check SavePath."
                $missing.Add($game)
            }
            else {
                # The exe is usually next to the save folder. GOG ScummVM
                # games have it elsewhere (Game\scummvm\scummvm.exe with saves
                # in Game\DAT\saves), so also look one and two folders up and
                # in the folders directly inside those.
                $roots = @($installDir, (Split-Path -Parent $installDir)) | Where-Object { $_ }
                $found = @($roots | ForEach-Object {
                        $_
                        Get-ChildItem -LiteralPath $_ -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
                    } | Where-Object { Test-Path -LiteralPath (Join-Path $_ $game.Exe) -PathType Leaf }).Count -gt 0
                if (-not $found) {
                    Write-Warning "$($label): $($game.Exe) was not found near '$installDir'. Fine if the exe lives elsewhere, but check SavePath and Exe."
                }
            }
        }
    }

    if ($problems.Count -gt 0) {
        throw ("Fix games.psd1 first:`n  - " + ($problems -join "`n  - "))
    }
    $found = @($games | Where-Object { -not $missing.Contains($_) })
    if ($found.Count -eq 0) {
        throw 'None of the games in games.psd1 were found on this PC. Check each SavePath.'
    }
    return $found
}

# One quoted "from;to" pair for CorrectFilePaths.
function Get-FixPair {
    param([Parameter(Mandatory = $true)] [hashtable] $Game)
    $target = $Game.UserStore.TrimEnd('\')
    if ($Game.RelativePaths) {
        $leaf = ($Game.SavePath.TrimEnd('\', '/') -split '[\\/]')[-1]
        # The fix parses its parameters like a command line, where \" is an
        # escaped quote: '...\Saves\"' would end the target in '"' instead of
        # '\' (seen in Process Monitor as 'Saves"test.dat'). '\\"' gives '\'.
        return ('"{0}\;{1}\\"' -f $leaf, $target)
    }
    return ('"{0};{1}"' -f $Game.SavePath.TrimEnd('\'), $target)
}

# The CorrectFilePaths parameters for all games that share one exe name.
function Get-FixCommandLine {
    param([Parameter(Mandatory = $true)] [object[]] $Games)
    # -b: apply only our corrections, none of the fix's built-in ones.
    return '-b ' + (($Games | ForEach-Object { Get-FixPair -Game $_ }) -join ' ')
}

# Games grouped by exe name. The fix matches an exe by name only and Windows
# applies just the first matching entry, so games that share an exe name
# (every GOG ScummVM game ships its own scummvm.exe) need one entry with all
# their paths, or only the first game would be redirected.
function Get-ExeGroup {
    param([Parameter(Mandatory = $true)] [object[]] $Games)
    $Games | Group-Object -Property { $_.Exe.ToLowerInvariant() } | ForEach-Object {
        [pscustomobject]@{
            Exe   = $_.Group[0].Exe
            Names = ($_.Group | ForEach-Object { $_.Name }) -join ', '
            Games = @($_.Group)
        }
    }
}

# --- compatibility database ------------------------------------------------------

function Initialize-SdbWriter {
    if ('Saveshim.Sdb' -as [type]) { return }
    # Documented shim-database writing functions exported by apphelp.dll.
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Saveshim {
    public static class Sdb {
        [DllImport("apphelp.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SdbCreateDatabase(string path, int pathType);
        [DllImport("apphelp.dll")]
        public static extern void SdbCloseDatabaseWrite(IntPtr pdb);
        [DllImport("apphelp.dll")]
        public static extern uint SdbBeginWriteListTag(IntPtr pdb, ushort tag);
        [DllImport("apphelp.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SdbEndWriteListTag(IntPtr pdb, uint tagId);
        [DllImport("apphelp.dll", CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SdbWriteStringTag(IntPtr pdb, ushort tag, string value);
        [DllImport("apphelp.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SdbWriteDWORDTag(IntPtr pdb, ushort tag, uint value);
        [DllImport("apphelp.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SdbWriteQWORDTag(IntPtr pdb, ushort tag, ulong value);
        [DllImport("apphelp.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SdbWriteBinaryTag(IntPtr pdb, ushort tag, byte[] data, uint size);
    }
}
'@
}

# Tag IDs from the shim database format (same values as ReactOS sdbtagid.h).
$Tag = @{
    Database        = [uint16]0x7001
    Library         = [uint16]0x7002
    Exe             = [uint16]0x7007
    MatchingFile    = [uint16]0x7008
    ShimRef         = [uint16]0x7009
    Name            = [uint16]0x6001
    Vendor          = [uint16]0x6005
    AppName         = [uint16]0x6006
    CommandLine     = [uint16]0x6008
    CompilerVersion = [uint16]0x6022
    OsPlatform      = [uint16]0x4023
    Time            = [uint16]0x5001
    ExeId           = [uint16]0x9004
    DatabaseId      = [uint16]0x9007
}

function New-CompatDatabase {
    # $Games is read inside the Write-List script blocks, which the analyzer
    # does not follow; the local helpers read better with positional arguments.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Games',
        Justification = 'Read inside a script block.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '',
        Justification = 'Local helpers.')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [object[]] $Games
    )
    if (-not $PSCmdlet.ShouldProcess($Path, 'write compatibility database')) { return }
    Initialize-SdbWriter
    $sdb = [Saveshim.Sdb]

    function Assert-Ok([bool] $ok, [string] $what) {
        if (-not $ok) { throw "Writing the compatibility database failed at: $what" }
    }
    function Write-List([uint16] $listTag, [scriptblock] $body, [string] $what) {
        $id = $sdb::SdbBeginWriteListTag($pdb, $listTag)
        Assert-Ok ($id -ne 0) "begin $what"
        & $body
        Assert-Ok ($sdb::SdbEndWriteListTag($pdb, $id)) "end $what"
    }
    function Write-Guid([uint16] $tag, [guid] $value, [string] $what) {
        $bytes = $value.ToByteArray()
        Assert-Ok ($sdb::SdbWriteBinaryTag($pdb, $tag, $bytes, [uint32]$bytes.Length)) $what
    }

    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path }
    $pdb = $sdb::SdbCreateDatabase($Path, 0)  # 0 = DOS_PATH
    if ($pdb -eq [IntPtr]::Zero) {
        throw "Could not create '$Path' (Windows error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
    }
    try {
        Write-List $Tag.Database {
            Assert-Ok ($sdb::SdbWriteQWORDTag($pdb, $Tag.Time, [uint64]([DateTime]::UtcNow.ToFileTimeUtc()))) 'time'
            Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.CompilerVersion, "saveshim $Version")) 'compiler version'
            Assert-Ok ($sdb::SdbWriteDWORDTag($pdb, $Tag.OsPlatform, 1)) 'platform'  # 1 = 32-bit (x86)
            Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.Name, $DatabaseName)) 'database name'
            Write-Guid $Tag.DatabaseId $DatabaseId 'database id'
            Write-List $Tag.Library {} 'library'

            foreach ($group in Get-ExeGroup -Games $Games) {
                $label = $group.Names
                Write-List $Tag.Exe {
                    Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.Name, $group.Exe)) "$label exe name"
                    Write-Guid $Tag.ExeId ([guid]::NewGuid()) "$label exe id"
                    Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.AppName, $label)) "$label app name"
                    Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.Vendor, 'saveshim')) "$label vendor"
                    # Match by file name only ("*" = the exe itself), so the
                    # fix keeps working after game updates.
                    Write-List $Tag.MatchingFile {
                        Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.Name, '*')) "$label matching file"
                    } "$label matching file"
                    Write-List $Tag.ShimRef {
                        Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.Name, 'CorrectFilePaths')) "$label fix name"
                        Assert-Ok ($sdb::SdbWriteStringTag($pdb, $Tag.CommandLine, (Get-FixCommandLine -Games $group.Games))) "$label fix parameters"
                    } "$label fix"
                } "$label entry"
            }
        } 'database'
    }
    finally {
        $sdb::SdbCloseDatabaseWrite($pdb)
    }
}

function Test-DatabaseInstalled {
    Test-Path -LiteralPath $InstalledKey
}

function Uninstall-CompatDatabase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if (-not (Test-DatabaseInstalled)) {
        Write-Host 'No earlier copy installed.'
        return
    }
    if ($PSCmdlet.ShouldProcess($DatabaseName, 'uninstall compatibility database')) {
        # sdbinst -u needs the installed copy's path; the registry has it.
        $installedPath = (Get-ItemProperty -LiteralPath $InstalledKey).DatabasePath
        & $Sdbinst -q -u $installedPath | Out-Null
        if (Test-DatabaseInstalled) {
            & $Sdbinst -q -u -g "{$DatabaseId}" | Out-Null
        }
        if (Test-DatabaseInstalled) {
            throw "Could not uninstall the old database ($installedPath). Remove it in Programs and Features ('$DatabaseName') and run this again."
        }
        Write-Host 'Removed the installed copy.'
    }
}

function Install-CompatDatabase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true)] [string] $Path)
    Uninstall-CompatDatabase
    if ($PSCmdlet.ShouldProcess($Path, 'install compatibility database for all users')) {
        $output = & $Sdbinst -q $Path 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-DatabaseInstalled)) {
            throw "sdbinst could not install '$Path' (exit code $LASTEXITCODE): $output"
        }
        Write-Host "Installed. It shows in Programs and Features as '$DatabaseName'."
    }
}

# --- user save folders -----------------------------------------------------------

# Every account that has a profile folder (has logged in at least once).
function Get-UserProfileList {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    foreach ($entry in Get-ChildItem -LiteralPath $key) {
        $sid = $entry.PSChildName
        # Real accounts are S-1-5-21-...; skips SYSTEM, services and "<SID>.bak".
        if ($sid -notmatch '^S-1-5-21-[\d-]+$') { continue }
        $profilePath = (Get-ItemProperty -LiteralPath $entry.PSPath).ProfileImagePath
        if (-not (Test-Path -LiteralPath $profilePath -PathType Container)) {
            Write-Warning "Profile folder '$profilePath' ($sid) is missing; skipped"
            continue
        }
        try {
            $account = ([Security.Principal.SecurityIdentifier]::new($sid)).Translate([Security.Principal.NTAccount]).Value
        }
        catch {
            Write-Warning "Account for '$profilePath' ($sid) no longer exists; skipped"
            continue
        }
        [pscustomobject]@{
            Account     = $account
            UserName    = ($account -split '\\')[-1]
            Sid         = $sid
            ProfilePath = $profilePath
        }
    }
}

# A UserStore template with the placeholders filled in for one user. The
# values are escaped for -replace, so a '$' in a path stays a '$'.
function Resolve-UserStore {
    param(
        [Parameter(Mandatory = $true)] [string] $Template,
        [Parameter(Mandatory = $true)] $UserProfile
    )
    $profilePath = $UserProfile.ProfilePath.TrimEnd('\')
    $path = $Template
    $path = $path -ireplace [regex]::Escape('%USERAPPDATA%'), (($profilePath + '\AppData\Roaming') -replace '\$', '$$$$')
    $path = $path -ireplace [regex]::Escape('%USERPROFILE%'), ($profilePath -replace '\$', '$$$$')
    $path = $path -ireplace [regex]::Escape('%USERNAME%'), ($UserProfile.UserName -replace '\$', '$$$$')
    return $path.TrimEnd('\')
}

function Initialize-UserStore {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true)] [object[]] $Games)
    $profiles = @(Get-UserProfileList)
    Write-Host "$($profiles.Count) account(s) with a user folder. Accounts that have never logged in are skipped; run this again after their first login."

    foreach ($userProfile in $profiles) {
        foreach ($game in $Games) {
            $store = Resolve-UserStore -Template $game.UserStore -UserProfile $userProfile
            if (Test-Path -LiteralPath $store -PathType Container) {
                Write-Host "  $($userProfile.Account), $($game.Name): $store (exists)"
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($store, "create save folder for $($userProfile.Account)")) { continue }

            New-Item -ItemType Directory -Path $store -Force | Out-Null
            $insideProfile = $store.StartsWith($userProfile.ProfilePath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
            if (-not $insideProfile) {
                # Outside the user's folder nothing grants the user access by
                # inheritance, so give them full control explicitly.
                & icacls.exe $store /grant "*$($userProfile.Sid):(OI)(CI)F" /Q | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Could not give $($userProfile.Account) access to '$store'" }
            }
            Write-Host "  $($userProfile.Account), $($game.Name): $store (created)"
        }
    }
}

# --- main ------------------------------------------------------------------------

# Dot-sourced (as the tests do): define the functions above, change nothing.
if ($MyInvocation.InvocationName -eq '.') { return }

Write-Host "saveshim $Version"
Assert-Admin

if ($Uninstall) {
    Write-Step 'Removing the compatibility database'
    Uninstall-CompatDatabase
    Write-Host 'Users'' save folders were kept.'
    return
}

Write-Step "Reading $ConfigPath"
$games = Get-GameList -Path $ConfigPath
foreach ($game in $games) {
    Write-Host "  $($game.Name): $($game.Exe), $($game.SavePath) -> $($game.UserStore)"
}

if (-not $StoresOnly) {
    Write-Step "Writing $SdbPath"
    foreach ($group in Get-ExeGroup -Games $games) {
        Write-Host "  $($group.Exe) ($($group.Names)): CorrectFilePaths $(Get-FixCommandLine -Games $group.Games)"
    }
    New-CompatDatabase -Path $SdbPath -Games $games
    if (-not $WhatIfPreference) { Write-Host '  Written.' }
}

Write-Step 'Creating users'' save folders'
Initialize-UserStore -Games $games

if (-not $StoresOnly) {
    Write-Step 'Installing the compatibility database'
    Install-CompatDatabase -Path $SdbPath
}

Write-Step 'Done'
Write-Host 'Start each game as a normal user (never "Run as administrator") and check that new saves appear in the user''s folder.'
