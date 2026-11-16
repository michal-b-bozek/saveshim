# 3. Write the database with apphelp.dll

- Status: accepted
- Date: 2026-11-14
- Deciders: Michał Bożek

## Context

`CorrectFilePaths` works only through a compatibility database (`.sdb`) that `sdbinst` installs.
Its parameters depend on where each game is installed, so the database differs from PC to PC.

The usual tool for writing one, Microsoft's Compatibility Administrator, comes with the Windows Assessment and Deployment Kit, a large download, and is used by hand.
Windows' own `apphelp.dll` has documented functions that write a database, which PowerShell can call with no download.

## Decision

1. **The script writes the database itself** with `apphelp.dll`, from `games.psd1`, on every run.
   The `.sdb` file is build output and is never committed.
2. **The database has a fixed ID**, so each run replaces the copy installed before it.
   The ID must never change.
3. **The database is for 32-bit programs.**
   Every tested game is 32-bit.
   Revisit when a 64-bit game needs saveshim.

## Consequences

- Changing a game means editing `games.psd1` and running the script again.
- The layout of the database follows ReactOS's headers, not Microsoft's docs; CI installs a real database to catch a layout `sdbinst` rejects.

## Options considered

- **Compatibility Administrator by hand:** a large download and many clicks per game, with no record of what was set.
- **A ready-made `.sdb` in the repository:** its paths would fit only one PC.
- **A third-party database compiler:** one more download to trust, for what `apphelp.dll` already does.
