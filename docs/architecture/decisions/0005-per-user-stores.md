# 5. Per-user stores

- Status: accepted
- Date: 2026-11-14
- Deciders: Michał Bożek

## Context

The redirect needs a target that differs per user, but the database is one file for the whole PC.
`CorrectFilePaths` fills in `%USERPROFILE%`, `%USERNAME%` and `%USERAPPDATA%` itself, for the user running the game.
It does not create the target folder.

## Decision

1. **Each game's `UserStore` is a path with at least one of those three placeholders.**
   The script rejects other placeholders, and a path with none, which every user would share.
2. **The script creates each user's folder**, for every account that has logged in at least once.
   A folder outside the user's profile gets full access for that user.
3. **The script never moves or deletes saves.**
   Moving old saves into the users' folders is a manual step in the README.

## Consequences

- An account that has never logged in gets its folders when the script runs again (`-StoresOnly`).
- Saves can go to another drive, such as `D:\savegames\%USERNAME%\Pharaoh`.

## Options considered

- **A logon script that creates the folders:** covers new users without a re-run, but runs at every login and is one more thing to install and remove.
- **Moving the old shared saves automatically:** the script cannot tell whose save is whose.
