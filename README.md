# eli5-gate

[![consistency](https://github.com/cooneycw/eli5-gate/actions/workflows/consistency.yml/badge.svg)](https://github.com/cooneycw/eli5-gate/actions/workflows/consistency.yml)

**The pre-implementation necessity gate for GitHub issues.** Before any code is
written, `/eli5 <issue>` answers three questions a reviewer actually cares about:

1. **What does this issue really want?** A plain-language (ELI5) restatement of
   intent - the fastest way to catch a misread before effort is spent.
2. **Should it still exist?** A staleness/necessity verdict anchored to the
   issue's creation date: everything merged *after* filing is inspected for work
   that already closed it, obsoleted it, or reframed it.
3. **What exactly will change?** A file-level plan presented for approval,
   redirect, or rejection - implementation is gated on the reviewer's yes.

Most issue-to-PR automation asks "how do we implement this?" This gate asks the
more valuable question first: "should this issue exist at all?"

## The four verdicts

| Verdict | What happens |
|---------|--------------|
| Still needed | Plan presented for approval; proceed as written once approved |
| Partially addressed | Only the remainder is planned and implemented |
| No longer needed | NEVER auto-implemented - a ready-to-paste evidence-based closing comment is offered instead |
| Needs reframing | The corrected approach is what gets approved, not the original ask |

## Install

**As a Claude Code plugin** (this repo is its own marketplace):

```
/plugin marketplace add cooneycw/eli5-gate
/plugin install eli5-gate@eli5-gate
```

**As an open-standard Agent Skill** (Claude Code, Codex, Cursor, and other
[agentskills.io](https://agentskills.io) harnesses) via [skills.sh](https://skills.sh):

```
npx skills add cooneycw/eli5-gate
```

Requirements: the `gh` CLI (authenticated) and a git checkout of the repository
the issue belongs to.

## Use

```
/eli5 42          # interactive: report, then wait for plan approval
/eli5 42 --yes    # unattended: report + auto-approve (except No longer needed)
```

Unattended pipelines can also opt in per-issue with an `eli5: auto-approve`
trailer in the issue body or HEAD commit message. A `No longer needed` verdict is
never auto-approved - it always stops for a human decision.

## Integrating into a pipeline

Run the gate between "analyze the issue" and "write the code". Treat the verdict
as control flow: `No longer needed` stops the pipeline with a close
recommendation; everything else pauses for approval (or proceeds under `--yes`)
and hands the APPROVED plan to the implementation step.

Reference integration:
[claude-power-pack](https://github.com/cooneycw/claude-power-pack)'s `/flow:auto`
runs this gate as Step 3 of its nine-step issue lifecycle. CPP vendors the
canonical core of this command (the `eli5-core` marker section in
[commands/eli5.md](commands/eli5.md)) and layers its flow-specific wiring around
it.

## Development

The gate's contract is restated in three files that must agree - the canonical
routine ([commands/eli5.md](commands/eli5.md), between the `eli5-core` markers),
the Agent Skill ([skills/eli5-gate/SKILL.md](skills/eli5-gate/SKILL.md)), and this
README - plus two packaging manifests. A single guard keeps them honest:

```
scripts/check-consistency.sh            # fail-open: reports drift, exits 0
scripts/check-consistency.sh --strict   # exits non-zero on any drift (used by CI)
```

It checks that the four verdict names match as a set across the restatements,
that key behavior tokens (`--yes` / `--auto-approve`, the `eli5: auto-approve`
trailer, the `createdAt` anchor, the read-only promise) are restated in SKILL.md,
that the `eli5-core` vendor markers are intact, and that
`.claude-plugin/plugin.json` / `marketplace.json` parse with their required
fields. The [`consistency`](.github/workflows/consistency.yml) GitHub Actions
workflow runs it with `--strict` on every push and pull request, so a stale
restatement or malformed manifest cannot merge unnoticed. Mirrors
claude-power-pack's own vendor+drift discipline.

## Provenance

Extracted from claude-power-pack's `/flow:eli5` (issue
[cooneycw/claude-power-pack#443](https://github.com/cooneycw/claude-power-pack/issues/443)),
where the gate was designed and battle-tested inside the `/flow:auto` issue
lifecycle. This repository is the canonical source; improvement issues for the
gate belong here, not in CPP.

Architecture decisions (why it's its own repo, the vendor-back mechanism, dual
packaging): [`docs/decisions/0001`](docs/decisions/0001-standalone-extraction-and-packaging.md).

## License

MIT
