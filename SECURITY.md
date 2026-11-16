# Security policy

Report a vulnerability privately through
[Security → Report a vulnerability](https://github.com/michal-b-bozek/saveshim/security/advisories/new),
not in a public issue.

saveshim is selfware with no support (see the [README](README.md)) and has no releases to patch:
there is only `main`. Reports are read, and a fix, if one is made, goes to `main`, with no
deadline.

`Install-Saveshim.ps1` runs as administrator and installs a compatibility database for all users.
Read it before you run it; it is one file, and it downloads nothing.
