# saveshim

Old games like Pharaoh keep their saves inside the game folder, so everyone on the PC shares
them. After this setup, every Windows user gets their own saves in their own folder, for example
`C:\Users\<user>\AppData\Roaming\Pharaoh\Saves`. It works whether the game is started from GOG
Galaxy or from the Start menu, and playing never needs administrator rights.

It uses a compatibility fix built into Windows, `CorrectFilePaths`. Windows applies it every time
the game starts. Nothing runs at login, and no game files are changed.

## About this project

This is selfware: a tool written for my own PC and shared as-is.

- All of the code and docs were written with an AI coding assistant (Claude Code).
- There is no support and no roadmap. It has been tested only with the games in the table below,
  on Windows 11.
- You are welcome to use, fork or republish it under the [MIT licence](LICENSE).

## Tested games

| Game                         | Installed by GOG Galaxy in                                                                                                       | Each user's saves go to                                        | Tested on Windows 11   |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------- |
| Pharaoh Gold                 | `C:\Program Files (x86)\GOG Galaxy\Games\Pharaoh Gold`<br>or `C:\Program Files\GOG Galaxy\Games\Pharaoh Gold`             | `C:\Users\<user>\AppData\Roaming\Pharaoh\Saves`                 | Working, November 2026 |
| Legend of Kyrandia (ScummVM) | `C:\Program Files (x86)\GOG Galaxy\Games\Legend of Kyrandia`<br>or `C:\Program Files\GOG Galaxy\Games\Legend of Kyrandia` | `C:\Users\<user>\AppData\Roaming\ScummVM\Saved games\Kyrandia` | Working, November 2026 |

Both install folders are GOG Galaxy defaults: which one you have depends on the version of GOG
Galaxy that was installed. saveshim looks in both. Other games whose saves sit in the game folder
should work too, if the game is a 32-bit program (see [Limits](#limits)). The examples here come
from GOG, but nothing in saveshim is specific to GOG.

## Quick install

For the games in the table, installed by GOG Galaxy in its own `Games` folder, with GOG Galaxy
in `C:\Program Files (x86)` or `C:\Program Files`, its default folders. For anything else, see
[Custom install](#custom-install). You need an administrator account.

1. On the [latest release](https://github.com/michal-b-bozek/saveshim/releases/latest), download
   `saveshim-<version>.zip`, not **Source code (zip)**: GitHub adds that to every release, and
   it holds the developers' files. Right-click the zip, choose **Extract All…**, and extract it
   to `C:\Tools\saveshim`.
2. Click Start, type `PowerShell`, right-click **Windows PowerShell**, and choose **Run as
   administrator**.
3. Type these two lines, pressing Enter after each:

   ```
   cd C:\Tools\saveshim
   powershell -ExecutionPolicy Bypass -File .\Install-Saveshim.ps1
   ```

   `-ExecutionPolicy Bypass` lets Windows run this one script, this one time. It changes no
   setting, and it ends when the script does.

4. Wait for `== Done`. A yellow line saying a game was skipped is fine if you don't have that
   game.
5. [Move the saves you already have](#move-existing-saves), then [check it](#check-it).

The setup creates each user's empty save folder and installs the fix for all users. The fix shows
in Programs and Features as "saveshim: per-user game saves". The setup also leaves
`saveshim.sdb` in its folder: that's the fix it installed, rewritten on every run. Keep the
folder: you need it again to add a game or a user, or to undo the setup.

## Custom install

For games in other folders, other games, or saves in another place. Download and extract as in
the quick install, then:

1. Find the game folder. In GOG Galaxy, open the game, click the settings button next to
   **Play**, and choose **Manage installation → Show folder**.
2. Open `games.psd1` (in the saveshim folder) with Notepad.
3. Change `SavePath` to the game's save folder, for example `D:\Games\Pharaoh Gold\Save`. This
   is the folder where the game itself would put its saves. For a ScummVM game, it's the
   `savepath=` line in the game's `.ini` file next to the game, for example `kyra1-cd.ini`.
   In the shipped entries, `SavePath` lists two places, one per line between `@(` and `)`.
   Replace the whole list with your one path in quotes: `SavePath = 'D:\Games\Pharaoh Gold\Save'`.
4. Leave `UserStore` as it is unless you want the saves somewhere else. `%USERAPPDATA%` becomes
   each user's own `C:\Users\<user>\AppData\Roaming` folder.
5. For a game that isn't in the list, see [Adding a game](#adding-a-game).
6. Save, close Notepad, and run the setup as in steps 2–4 of the quick install. To see what it
   would do without changing anything, add `-WhatIf` at the end of the second line. If it stops
   with a red message, the message says what to fix, usually a path in `games.psd1`. Fix it and
   run the setup again.

## Move existing saves

Saves already in the shared game folder aren't moved: copy each user's saves into their own
folder.

- **Pharaoh** keeps one `<Dynasty>.dat` file and one `<Dynasty>` folder per player; both must sit
  directly in `Saves`:
  - Right: `C:\Users\<user>\AppData\Roaming\Pharaoh\Saves\MyDynasty.dat` and
    `...\Saves\MyDynasty\`
  - Wrong: `...\Pharaoh\Saves\Save\MyDynasty.dat`
- **ScummVM games** keep files like `kyra1-cd.001` (the game's name and a number); they go
  directly in the game's folder, for example `...\ScummVM\Saved games\Kyrandia\kyra1-cd.001`.

## Check it

Log in as the user. Start the game, save, and quit. The new save must appear in that user's
folder, and the game's own save folder must stay empty.

If something doesn't work, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Later

Every command below runs in a PowerShell opened with **Run as administrator**, in the saveshim
folder (`cd C:\Tools\saveshim`), as in the quick install.

- **A new person gets a Windows account:** after their first login, run
  `powershell -ExecutionPolicy Bypass -File .\Install-Saveshim.ps1 -StoresOnly`. It creates their
  save folders.
- **You change `games.psd1`:** run `powershell -ExecutionPolicy Bypass -File .\Install-Saveshim.ps1`
  again. That's safe.
- **Never** start the game with "Run as administrator". Windows then skips the fix and the game
  uses the shared folder.
- If the game has GOG cloud saves, turn them off for it in Galaxy. Galaxy would otherwise copy one
  person's saves into the shared folder.
- The game keeps a few small files in its own folder that are not saves. These stay shared:
  - Pharaoh: `Pharaoh.inf` (last dynasty name) and `Pharaoh.ini`, so a user may see someone
    else's dynasty name suggested.
  - ScummVM: the game's `.ini` (volume, fullscreen and other settings).

## Adding a game

Add an entry to `games.psd1` and run the setup again. The comments at the top of `games.psd1`
explain each line. If it works, you're welcome to propose the entry for the shipped list; see
[CONTRIBUTING.md](CONTRIBUTING.md#proposing-a-game).

- **`Exe`** is the file name of the game's program. For a GOG game, open the `goggame-*.info`
  file in the game folder with Notepad: it's the file name in the `path` of the `playTasks` entry
  with `"isPrimary": true`.
- **`RelativePaths = $true`** is needed when the game opens its saves by a short path like
  `Save\file.sav` instead of the full path. Pharaoh does. If saves still land in the game folder
  with it off, try it on.
- **Check that the game is a 32-bit program.** Start it, open Task Manager (Ctrl+Shift+Esc), go
  to **Details**, right-click a column header, choose **Select columns**, and tick **Platform**.
  The game's line must say **32 bit**.

For another GOG ScummVM game, copy the Kyrandia entry and change `Name`, `SavePath` (from the
game's `.ini`) and the last part of `UserStore`, so each game gets its own folder under
`%USERAPPDATA%\ScummVM\Saved games`, ScummVM's own default save folder. Every GOG ScummVM game
ships its own `scummvm.exe`, and Windows applies only one fix per program name, so the setup
combines all games with the same `Exe` into one fix. Each game's save folder is still redirected
separately.

ScummVM must be started with the game's own settings file, as GOG's shortcut does:
`scummvm.exe -c "..\kyra1-cd.ini" kyra1-cd`, starting in the game's `scummvm` folder. If the game
is added to Galaxy by hand (a custom or "Generic" game), give it these arguments, or link GOG's
`Launch ... .lnk` shortcut instead of `scummvm.exe`. Started without them, ScummVM opens its own
launcher and saves to its default folder instead of the game's.

## Limits

- **32-bit games only.** The fix is written for 32-bit programs; it has not been tried with a
  64-bit game, and you should not expect it to work there.
- **The fix goes by program name only.** Every program called, say, `scummvm.exe` on this PC gets
  the fix, in any folder, including a ScummVM you installed yourself. That's harmless unless the
  other program also uses one of the listed save folders. The upside is that the fix keeps
  working after a game update.
- **"Run as administrator" skips it.** A game started as administrator writes to the shared
  folder.
- **Accounts that have never logged in** get no save folder until you run `-StoresOnly` after
  their first login.
- **Tested on Windows 11 only.**

## Why not just…

- **…let Windows do it?** Windows already has a redirect for old programs, UAC virtualization (the
  "VirtualStore"): when an old 32-bit program writes somewhere normal users may not write, such as
  `C:\Program Files`, Windows sends the write to that user's own folder instead. But GOG game
  folders normally let every user write to them, so the write succeeds, nothing is redirected,
  and everyone shares the saves.
- **…link the save folder somewhere else?** A link points to one place for everyone. Switching it
  per user needs a script at every login or game start, and it breaks when two people are logged
  in at once.

The full reasoning is in the [decision records](docs/architecture/decisions/).

## Undo

As administrator, in the saveshim folder:
`powershell -ExecutionPolicy Bypass -File .\Install-Saveshim.ps1 -Uninstall`. Users' save folders
and their saves are kept where they are. The setup never deletes anyone's saves.

## What's in the folder

| File                       | What it does                                                         |
| -------------------------- | -------------------------------------------------------------------- |
| `Install-Saveshim.ps1`     | Sets everything up (administrator)                                   |
| `games.psd1`               | Where each game's saves are, and where each user's saves go          |
| `TROUBLESHOOTING.md`       | What to check when the game doesn't see the saves                    |
| `README.md`, `LICENSE`     | This page, and the [MIT licence](LICENSE)                            |
| `saveshim.sdb`             | Created by the setup: the fix it installed                           |

The release zip holds only these files. The repository itself also has `docs/`, `tests/` and
`tools/`, which are for developers only: see the [developer guide](docs/development.md).

To check that a release zip is the one this repository built, compare it with the `.sha256` file
next to it on the release page, or run
`gh attestation verify saveshim-<version>.zip --repo michal-b-bozek/saveshim` with the
[GitHub CLI](https://cli.github.com/).

## More

- How it works: [docs/design.md](docs/design.md); why:
  [architecture decision records](docs/architecture/decisions/).
- Development and tests: [docs/development.md](docs/development.md); before a release:
  [manual test protocol](docs/testing.md).
- Changes: [CHANGELOG](CHANGELOG.md). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md). Security
  reports: [SECURITY.md](SECURITY.md).
- Licence: [MIT](LICENSE).
