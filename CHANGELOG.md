# Changelog

## [Unreleased]

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
