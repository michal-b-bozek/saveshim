# 2. Redirect with CorrectFilePaths

- Status: accepted
- Date: 2026-11-14
- Deciders: Michał Bożek

## Context

Old games such as Pharaoh, and the ScummVM games GOG sells, keep their saves in the game folder.
On a PC with several Windows accounts, everyone shares them.
Each user should get their own saves, however the game is started, with several people logged in at once, without administrator rights to play, and without changing the game's files.

Windows already redirects some writes of old 32-bit programs to a per-user folder (UAC virtualization, the "VirtualStore"), but only writes that would be denied.
GOG game folders normally let every user write to them, so nothing is redirected.

Windows also has a compatibility fix, `CorrectFilePaths`, that changes the file paths a program asks for before Windows opens the file.
Windows applies it at every start of a program listed in an installed compatibility database.

## Decision

1. **saveshim redirects each game's save folder with `CorrectFilePaths`**, from the folder in the game's install to a folder per user ([ADR 5](0005-per-user-stores.md)).
2. **Only the save folders listed in `games.psd1` move.**
   Other files a game keeps in its folder stay shared.

## Consequences

- Nothing runs at login or when the game starts; Windows does the work, wherever the game is started from.
- A game started with "Run as administrator" is not redirected.
- The fix has little documentation, so its details were found by trying it, with Process Monitor.

## Options considered

- **Rely on VirtualStore:** does nothing for folders users may write to, as GOG's normally are.
  Taking away their write access was not tried: VirtualStore only covers 32-bit programs without a manifest, puts the saves in a fixed place, and still shows the old shared saves.
- **A link from the save folder to a user's folder:** one target for everyone; switching it per user needs a script at each login or game start, and breaks with two users logged in.
- **A launcher script:** skipped when the game is started from Galaxy or another shortcut.
- **One copy of the game per user:** several times the disk space, and every update installed per user.
- **The game's own save-path setting:** only some games have one.
