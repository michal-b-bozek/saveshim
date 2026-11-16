# Troubleshooting: the game doesn't see the saves

## 1. Is the fix installed?

In any PowerShell:

```
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom\Pharaoh.exe'
```

(For a ScummVM game, use `scummvm.exe` instead of `Pharaoh.exe`.)

`False` means it isn't installed: run the setup again as the README
describes, and make sure it ends with "Installed" and `== Done`. Once
installed, it shows in Programs and Features as "saveshim: per-user game
saves".

## 2. Is the game started the right way?

- Start it from the Start menu or GOG Galaxy, as a normal user. Never with
  "Run as administrator": Windows then skips the fix.
- Make sure no other tool changes the game's `Save` folder, such as an old
  launcher script that turns it into a link. The game's `Save` folder should
  be a plain, empty folder.

## 3. Find out where new saves go

Start the game, load or start a dynasty, save a game called `test`, quit.
Then look for it:

- **In the game's `Save` folder:** the fix isn't catching the game's paths.
  Check `RelativePaths` in `games.psd1` (Pharaoh needs `$true`), re-run the
  setup and try again. If that doesn't help, go to step 5.
- **In `%APPDATA%\Pharaoh\Saves`, but old saves aren't listed:** the
  copied saves are in the wrong place. Go to step 4.
- **ScummVM game, saves directly in `%APPDATA%\ScummVM\Saved games` (not
  its subfolder), or ScummVM's own game list opens instead of the game:**
  ScummVM was started without the game's settings file. The last lines of
  `%APPDATA%\ScummVM\Logs\scummvm.log` then say `Default configuration file
  missing` instead of `Using configuration file: ..\<game>.ini`. Start it
  with GOG's arguments, e.g. `-c "..\kyra1-cd.ini" kyra1-cd` (see "Adding a
  game" in the README). Galaxy's log
  (`C:\ProgramData\GOG.com\Galaxy\logs\GalaxyClient.log`, lines with
  `Launching process`) shows which arguments it passed.
- **ScummVM game, checking the path in ScummVM:** the game's **Options →
  Paths** still shows the game's own save folder, because the fix redirects
  it underneath. Look for the new save in the game's
  folder under `%APPDATA%\ScummVM\Saved games`, e.g. `...\Kyrandia`. A
  shortcut that adds `--savepath=...` to the command line bypasses the fix;
  that's fine as long as it points at the same folder.
- **Nowhere, and the game can't create a new dynasty or doesn't list any:**
  the fix catches the paths but sends them to a wrong place. Go to step 5.

## 4. The saves are in the wrong place

Pharaoh keeps one `<Dynasty>.dat` file and one `<Dynasty>` folder per player.
Both must sit directly in `Pharaoh\Saves`:

- Right: `C:\Users\<user>\AppData\Roaming\Pharaoh\Saves\MyDynasty.dat` and
  `...\Saves\MyDynasty\`
- Wrong: `...\Pharaoh\Saves\Save\MyDynasty.dat`

The wrong one happens when the whole `Save` folder is copied in. Move its
contents up one level and delete the empty `Save` folder.

## 5. Record the game's file access

Process Monitor shows every file the game opens and why it failed.

1. Download Process Monitor from
   <https://learn.microsoft.com/sysinternals/downloads/procmon> and unzip it.
2. Right-click `Procmon64.exe`, choose **Run as administrator**. Accept the
   licence.
3. In the **Process Monitor Filter** window: set `Process Name` `is`
   `Pharaoh.exe` (or `scummvm.exe`), choose **Include**, click **Add**, then
   **OK**.
4. Start Pharaoh normally (not as administrator). Open the dynasty screen,
   try to create a new dynasty, and try to load a save. Quit the game.
5. In Process Monitor, look at the paths containing your save folder. The
   **Result** column says what went wrong, for example `NAME INVALID` for a
   malformed path or `PATH NOT FOUND` for a folder that doesn't exist.
6. To keep a record, or to show someone who helps you: **File → Save…**,
   **Events displayed using current filter**, **Comma-Separated Values
   (CSV)**. The file contains your Windows user name and folder names; look
   through it before you share it.

saveshim comes with no support (see the README), so there is no one to send
the file to by default.
