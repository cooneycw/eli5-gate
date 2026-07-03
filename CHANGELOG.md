# Changelog

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
