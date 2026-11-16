# Manual test protocol

Run this before every release, from the release zip (`mise run pack`, or a release candidate's
draft release), on a Windows PC with at least one game from the
[tested games](../README.md#tested-games) and two standard user accounts besides the
administrator. `mise run test` checks the logic, and CI's smoke test checks that the database
installs and uninstalls; this protocol checks what only a real game and real accounts show: that
the saves move.

A **Check** must hold, or the case fails; a **Record** is an observation to write down. Write
down, per run: the Windows version (`winver`), the games and how they were installed (Galaxy or
offline installer), and pass or what differed for each case.

Run every command in a PowerShell opened with **Run as administrator**, in the saveshim folder,
after `Set-ExecutionPolicy -Scope Process Bypass`.

## 1. Install

1. Leave `games.psd1` as shipped if GOG Galaxy installed the games in its own `Games` folder,
   with GOG Galaxy in `C:\Program Files (x86)` or `C:\Program Files` (the quick install);
   otherwise edit it. Run `.\Install-Saveshim.ps1 -WhatIf`. **Check:** it lists each game found
   and the `CorrectFilePaths` parameters, warns about each game not on this PC, ends with
   `== Done`, and no `saveshim.sdb` appears.
2. Run `.\Install-Saveshim.ps1`. **Check:** its first line is `saveshim <version>`, the version
   of the release; it ends with "Installed" and `== Done`; Programs and
   Features lists "saveshim: per-user game saves"; each user has an empty save folder.

## 2. Saves move, per user

For each of the two users:

1. Log in, start each game from GOG Galaxy, save a game named after the user, and quit.
2. **Check:** the save is in that user's folder, and the game's own save folder stays empty.
3. Start the game from the Start menu and load the save. **Check:** it loads.

**Check:** neither user sees the other's save.

## 3. Run as administrator

As the administrator, start one game with "Run as administrator" and save. **Record:** where the
save went. The docs say it goes to the shared folder; delete it afterwards.

## 4. A new user

1. Create a third account and log in once.
2. As administrator, run `.\Install-Saveshim.ps1 -StoresOnly`. **Check:** it creates the new
   user's folders only and leaves the installed fix alone.
3. As the new user, save in one game. **Check:** the save is in their folder.

## 5. Re-run

Run `.\Install-Saveshim.ps1` again. **Check:** "Removed the installed copy", then "Installed";
Programs and Features lists one saveshim entry; the users' saves are untouched.

## 6. Uninstall

Run `.\Install-Saveshim.ps1 -Uninstall`. **Check:** Programs and Features no longer lists
saveshim; the users' folders and saves are still there; a new save in a game goes to the game's
own folder.
