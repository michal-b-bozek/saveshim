# 6. One script

- Status: accepted
- Date: 2026-11-14
- Deciders: Michał Bożek

## Context

The people who set saveshim up are admins of a family or small-office PC, often not technical.
They follow the steps in the README, in Windows PowerShell 5.1, which every Windows 10 and 11 PC has.
The tests need to load the script's functions without running the setup, which needs administrator rights and changes the machine.
The repository also holds docs, tests and tools that users don't need, and someone reporting a problem should be able to say which version they ran.

## Decision

1. **Everything the setup does is in one file, `Install-Saveshim.ps1`**, next to `games.psd1`.
   It needs no module, download or build step.
2. **The script runs in Windows PowerShell 5.1 and in PowerShell 7.**
3. **Loading the script with `.` (dot-sourcing) only defines its functions**, which is how the tests load it.
4. **A release is a zip of only the files users need**: the script, `games.psd1`, the README, the troubleshooting guide and the licence.
   CI builds it from a version tag, with a checksum and a signed record of where it was built.
5. **The script carries its version** in one line, and prints it at the start of every run.

## Consequences

- Users handle one script and one config file, and the README stays a short list of steps.
- The script is longer than a module would be.
- A release needs a version tag and a CI run, and the version line must match the tag.

## Options considered

- **A PowerShell module plus a small script:** two files to keep together and a module path to get right, for no gain to the user.
- **An installer (MSI or exe):** a build step, and signing to avoid SmartScreen warnings, for a tool that runs once.
- **GitHub's own source zip of the repository:** no build, but users would have to find three files among the developers' ones.
- **A zip built and uploaded by hand:** no one could check how it was made.
