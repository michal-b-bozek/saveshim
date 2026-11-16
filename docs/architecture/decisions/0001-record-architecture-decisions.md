# 1. Record architecture decisions

- Status: accepted
- Date: 2026-11-14
- Deciders: Michał Bożek

## Context

A few saveshim choices look odd without their reasons: a Windows compatibility fix instead of a folder link, a database written by the script itself, programs matched by name only.
People and coding agents read only what is in the repository.

Detail such as parameters, messages and registry paths changes with the code.
Written into an ADR, it hides the decision.

## Decision

1. One decision per file, `docs/architecture/decisions/NNNN-short-title.md`, with Context, Decision, Consequences and Options considered.
2. An ADR records a choice that is costly to reverse or that later changes must follow.
   How the code works is in `docs/design.md`.
3. Numbers run from 1 with no gaps; `README.md` here lists every ADR.
4. Until the first release, an accepted ADR may be edited in place, and the commit says why.
   From then on, a refinement goes in a dated `> **Amendment (YYYY-MM-DD).**` note under the item it changes, and a reversal needs a new ADR that supersedes the old one, with links both ways.
5. Plain English, under 800 words, one sentence per line.

## Consequences

- A reader finds the options already rejected before proposing them again.
- Each such decision costs a page of writing.

## Options considered

- **Reasons in `docs/design.md` only:** the page describes what is, and loses the rejected options when it changes.
- **Commit messages only:** a decision spread over several commits has no single place.
