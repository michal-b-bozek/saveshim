# Architecture decision records

[ADR 1](0001-record-architecture-decisions.md) sets the form and rules of these records.

## Terms

- **Fix:** one of the compatibility fixes built into Windows, also called a shim: a change Windows makes to how one program calls Windows, here `CorrectFilePaths` ([ADR 2](0002-redirect-with-correctfilepaths.md)).
- **Database:** a `.sdb` file that says which programs get which fixes; `sdbinst` installs it ([ADR 3](0003-write-the-database-with-apphelp.md)).
- **Entry:** one program in the database, found by its exe name ([ADR 4](0004-match-by-exe-name-only.md)).
- **User store:** the folder a user's saves go to ([ADR 5](0005-per-user-stores.md)).

## Records

1. [Record architecture decisions](0001-record-architecture-decisions.md)
2. [Redirect with CorrectFilePaths](0002-redirect-with-correctfilepaths.md)
3. [Write the database with apphelp.dll](0003-write-the-database-with-apphelp.md)
4. [Match by exe name only](0004-match-by-exe-name-only.md)
5. [Per-user stores](0005-per-user-stores.md)
6. [One script](0006-one-script.md)
