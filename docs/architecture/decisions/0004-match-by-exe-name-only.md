# 4. Match by exe name only

- Status: accepted
- Date: 2026-11-14
- Deciders: Michał Bożek

## Context

A database entry names a program and can also require file details, such as size, checksum or version.
These details keep the fix off other programs with the same name.
They also stop the fix after a game update, and then the saves quietly go back to the shared folder.
GOG Galaxy updates games on its own.

Every GOG ScummVM game ships its own `scummvm.exe`.
Windows applies only the first entry that matches a program.

## Decision

1. **An entry matches the game's exe by name only**, with no file details.
2. **Games with the same exe name share one entry**, which redirects each of their save folders.
   `games.psd1` still lists one game per entry, and the script combines them.

## Consequences

- The fix keeps working after game updates.
- Every program with that name on the PC gets the fix, in any folder.
  This matters only if that program also uses one of the listed save folders.
- Adding another ScummVM game is a copied block in `games.psd1`.

## Options considered

- **Name plus file details:** no stray matches, but the redirect stops at the first update and nothing tells the user.
- **Also require a file next to the exe**, such as GOG's `goggame-*.info`: fewer stray matches, one more thing to set per game.
  Revisit if a stray match causes trouble.
- **One entry per game:** only the first game with a shared exe name would be redirected.
