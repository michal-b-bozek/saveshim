# Contributing

saveshim is selfware: written for one PC and shared as-is, without day-to-day support or a
roadmap (see the [README](README.md)). Questions, ideas and game proposals are welcome as issues,
and I'll get to them when I have spare time. If you need it to work differently sooner, you're
welcome to fork it; the [MIT licence](LICENSE) allows it.

If you send a pull request:

- Keep it to one change, in [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
- Run `mise run check` first; the [developer guide](docs/development.md) sets it up.
- Read the [decision records](docs/architecture/decisions/) before changing a design choice; a new
  choice that is costly to reverse gets its own record.
- No personal data: no real user names, machine paths or email addresses.

## Proposing a game

New entries for `games.psd1` are welcome, as an issue or a pull request. The shipped list is what
the quick install in the README runs unchanged, so an entry must work with the game's default
installation:

- **`SavePath`** in the folder the store's own client installs to by default, with its default
  settings. For GOG, list both of GOG Galaxy's default folders, as the existing entries do:
  `C:\Program Files (x86)\GOG Galaxy\Games\<Game>` and `C:\Program Files\GOG Galaxy\Games\<Game>`.
  Which one a PC has depends on the version of GOG Galaxy installed.
- **`UserStore`** under `%USERAPPDATA%`, like the existing entries: `%USERAPPDATA%\<Game>\Saves`,
  or for a ScummVM game `%USERAPPDATA%\ScummVM\Saved games\<Game>`.
- **Tested:** a normal user's new save landed in their own folder, on the Windows version you
  name. Add the game to the README's table, with both install folders and where the saves
  go.
- **32-bit:** the game's exe shows "32 bit" in Task Manager (see "Adding a game" in the README).

Security problems go through [SECURITY.md](SECURITY.md), not an issue.
