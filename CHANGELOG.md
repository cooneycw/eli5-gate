# Changelog

## [Unreleased]

- **The gate has no bypass** (claude-power-pack#775) - BREAKING for callers that
  passed `--yes`. All three approval-skipping channels are removed:
  `--yes`, its `--auto-approve` alias, and the `eli5: auto-approve` trailer read
  from the issue body or HEAD commit message. The flags are still recognized, but
  only to tell a caller the gate is not skippable; the run pauses anyway. The
  trailer is no longer read at all.

  The trailer was the sharper edge and the reason this is a removal rather than a
  warning: it is not chosen by whoever runs the command. An issue body is written
  by whoever filed the issue, and on a branch freshly cut from the default branch
  HEAD *is* the tip commit - written by whoever merged last. One merged commit
  carrying the trailer disarmed the gate for every subsequent run branched from
  that tip, across unrelated issues and unrelated sessions, with no flag passed
  and no invoker at fault. Downstream, claude-power-pack found the mechanism
  already live rather than latent: the very commit that declined to propagate the
  trailer to its other drivers contained the literal string, and so did the bug
  report about it.

  The flags go with it because the same structural argument covers them: an
  invocation flag is typed *before* Section C exists, so it can never be an
  approval **of** the plan - only standing consent to whatever plan the run later
  produces. `AUTO-GRANTED` leaves the report vocabulary entirely; if the field can
  still be produced, something can still skip the gate. Unattended callers are not
  an exception - a pipeline that cannot pause is one whose plans are never
  reviewed.

  Both classes of removed channel stay *named* in `commands/eli5.md` and
  `SKILL.md` so a future editor reinstates one deliberately rather than by
  accident, and `scripts/check-consistency.sh` pins those names plus the
  "The gate has no bypass" sentence itself.

- Section A depth floor (#3): the ELI5 intent section now carries an explicit
  floor of its own, parallel to the Sections B/C floors - motivation before
  mechanics, a plain-language gloss on every technical term at first use, and the
  explain-like-I'm-five bar stated outright (a reader who has never seen the
  codebase must understand what is wrong today and what will be better). Length
  guidance relaxed from "two to four sentences" to a two-to-four-sentence
  *minimum* so it no longer fights the floor. Mirrored in SKILL.md.
- Report depth floor (claude-power-pack#509): Section B must enumerate the actual
  commit SHAs / PR numbers / issue numbers inspected (or an explicit "none");
  Section C must list every file on its own numbered line with a scope estimate
  and a named risk. The output-format template is now explicitly a floor, not a
  ceiling, regardless of the model's verbosity profile. Mirrored in SKILL.md.
- Internal consistency guard `scripts/check-consistency.sh` (#1): keeps the four
  verdict names and key behavior tokens in `skills/eli5-gate/SKILL.md` and
  `README.md` in sync with the canonical `eli5-core` section of
  `commands/eli5.md`, checks the vendor markers are intact, and validates
  `.claude-plugin/plugin.json` / `marketplace.json` parse with required fields.
  Fail-open locally (exits 0, reports drift); `--strict` blocks in CI.
- `consistency` GitHub Actions workflow runs the guard with `--strict` on every
  push and pull request.
- SKILL.md now restates the `--auto-approve` alias of `--yes` (drift the new
  guard caught on its first run).

## [1.0.0] - 2026-07-03

Initial release, extracted from claude-power-pack's `/flow:eli5`
(cooneycw/claude-power-pack#443).

- `/eli5 <issue> [--yes]` command: plain-language intent ELI5, necessity/staleness
  verdict (Still needed / Partially addressed / No longer needed / Needs
  reframing) anchored to the issue's `createdAt`, and a plan-approval gate.
- `No longer needed` is never auto-approved; the gate offers an evidence-based
  closing comment instead of implementing.
- Packaged both as a self-hosting Claude Code plugin marketplace
  (`.claude-plugin/plugin.json` + `marketplace.json`) and as an open-standard
  Agent Skill (`skills/eli5-gate/SKILL.md`) for skills.sh installation.
- The `eli5-core` marker section in `commands/eli5.md` is the canonical core that
  downstream vendors (claude-power-pack) sync against.
