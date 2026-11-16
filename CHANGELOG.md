# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog 1.1](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning 2.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

<!-- cocogitto inserts each release below this separator (cog bump); keep it. -->
- - -
## [0.1.0] - 2026-11-16

### Added

- `Install-Saveshim.ps1` gives every Windows user on a shared PC their own saves, for old games
  that keep their saves in the game folder. It uses a compatibility fix built into Windows, so
  nothing in the games or in GOG Galaxy is changed, and playing never needs administrator rights.
- `games.psd1` lists Pharaoh Gold and Legend of Kyrandia, tested on Windows 11 with the GOG Galaxy
  versions. It finds them in GOG Galaxy's `Games` folder, with GOG Galaxy in
  `C:\Program Files (x86)` or `C:\Program Files`, and skips a game that isn't installed.
- `-StoresOnly` creates the save folders for a user added later. `-Uninstall` removes the fix and
  keeps every user's saves.
- Each release is a zip of only the files you need, with a SHA-256 checksum and a signed record of
  where it was built.

- - -

[Unreleased]: https://github.com/michal-b-bozek/saveshim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/michal-b-bozek/saveshim/releases/tag/v0.1.0
