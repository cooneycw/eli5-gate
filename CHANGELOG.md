# Changelog

## [Unreleased]

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
