# ADR 0001: Standalone extraction and packaging

- Status: Accepted
- Date: 2026-07-03
- Deciders: cooneycw (owner)
- Provenance: extracted from [claude-power-pack](https://github.com/cooneycw/claude-power-pack)'s
  `/flow:eli5` (issue #443). CPP's extract-vs-keep rationale lives in CPP's ADR
  `docs/decisions/0001-plugin-marketplace-packaging.md`; this ADR records the
  decisions specific to *this* repo.

## Context

The ELI5 necessity gate ("should this issue exist at all?") was designed and
battle-tested inside CPP's `/flow:auto` lifecycle. It has standalone value that
nothing else in the ecosystem offers, so it is now distributed independently. A
reader of *this* repo should understand its architecture without reference to
CPP.

## Decisions

### 1. This repo is the canonical source; CPP vendors the core back

Rather than CPP depending on the installed plugin at runtime, CPP **vendors** the
canonical core of the command (the section delimited by `eli5-core` markers in
`commands/eli5.md`) byte-identical into its own copy, with an advisory drift
check (`scripts/eli5-core-drift.sh` in CPP) against this repo's raw file.

Rationale: CPP must work offline and without installing this plugin, but the gate
logic must not fork. Vendoring the marked core keeps one source of truth (here)
while letting CPP layer its flow-specific wiring outside the markers. Improvement
issues for the gate belong in this repo, not CPP.

### 2. Dual packaging: Claude Code plugin AND open-standard Agent Skill

The repo ships both:
- `.claude-plugin/plugin.json` + `marketplace.json` - a self-hosting plugin
  marketplace (`/plugin marketplace add cooneycw/eli5-gate`).
- `skills/eli5-gate/SKILL.md` - [agentskills.io](https://agentskills.io)
  packaging installable via `npx skills add cooneycw/eli5-gate` across ~40
  harnesses (Claude Code, Codex, Cursor, and others).

Rationale: the two distribution channels reach different audiences; shipping both
from one repo costs little and maximizes reach without a second source of truth.

### 3. The command is generalized (de-CPP'd) so it stands alone

`commands/eli5.md` keeps the same three-section report, four verdicts, and
`--yes` / `eli5: auto-approve` semantics, but with no dependency on CPP's
`/flow:auto`. The `No longer needed` verdict is never auto-approved. It runs
against any repo the issue belongs to with just an authenticated `gh` CLI.

## Consequences

- One source of truth for the gate logic (here); CPP and any other consumer stay
  in sync via vendoring + drift check, not a hard runtime dependency.
- The gate is installable two ways and usable outside CPP entirely.
- A change to the gate's core is made here and flows to CPP through the drift
  check, not the other way around.
