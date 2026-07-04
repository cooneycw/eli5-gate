# ELI5 Necessity Gate

The pre-implementation checkpoint for issue-driven development. Before any code is
written: restate the issue's intent in plain language, check whether the issue is
still worth doing given everything merged since it was filed, and present the
proposed changes for reviewer approval.

Most issue-to-PR automation asks "how do we implement this?" This gate asks the
more valuable question first: "should this issue exist at all?"

## Arguments

- `ISSUE` (required): GitHub issue number (e.g., `42`)
- `--yes` (optional, alias `--auto-approve`): skip the interactive approval pause
  for unattended runs. The ELI5 report is still produced and recorded. A `No
  longer needed` verdict is NEVER auto-approved - it always stops for a human
  decision.

## Requirements

- `gh` CLI, authenticated for the repository's GitHub remote
- Run from inside the git repository the issue belongs to

<!-- eli5-core:begin (canonical: https://github.com/cooneycw/eli5-gate commands/eli5.md) -->
## What this is for

Automated implement-from-issue pipelines jump from analysis straight to
implementation with only a terse implementer-facing plan in between. That gives a
human reviewer no clear, plain-language checkpoint to approve, redirect, or reject
before effort is spent. Two gaps in particular:

1. **No staleness / necessity check.** An issue filed weeks ago may already be
   solved (or made obsolete) by code merged since. The default flow assumes the
   issue is still valid and just implements it.
2. **No reviewer-friendly intent summary.** The implementer-term plan is not the
   fastest way for a reviewer to catch a misread of intent.

This gate closes both gaps: it tells the reviewer, in their language, what the
issue means, whether it is still worth doing, and what will change - then waits
for approval.

## Instructions

When the gate is invoked with an issue number, perform the following. This command
is read-only with respect to the codebase: it inspects and reports, it does not
write implementation code.

### Step 1: Gather context

If this gate is being run as a step inside a larger pipeline that has already
analyzed the issue, reuse that analysis and skip re-reading the codebase. When run
standalone, gather context first:

```bash
ISSUE_NUM="$1"
# Pull the body AND the creation timestamp - the timestamp drives staleness.
gh issue view "$ISSUE_NUM" --json number,title,state,body,createdAt,labels,closedAt
ISSUE_DATE=$(gh issue view "$ISSUE_NUM" --json createdAt --jq '.createdAt')
```

- Parse acceptance criteria (`- [ ]` items), referenced files/components, and any
  task IDs or dependencies.
- Read the files the issue references and the surrounding patterns so the
  proposed-changes section is concrete.

### Step 2: Produce the three-section report

Emit all three sections every time. Do not skip a section even if it is short.

**Section A - ELI5 overview of intent.** A plain-language restatement of what the
issue is trying to accomplish and why, free of implementation jargon. Two to four
sentences a non-author reviewer can sanity-check for a misread of intent.

**Section B - Necessity / staleness analysis.** Assess whether the issue is still
necessary given the current code and anything merged *after* it was filed. Inspect
post-filing history explicitly:

```bash
# Commits landed since the issue was filed (global, then scoped to the files
# the issue touches - substitute the relevant paths).
git log --since="$ISSUE_DATE" --oneline
git log --since="$ISSUE_DATE" --oneline -- <relevant/paths>

# Pull requests merged since the issue was filed.
gh pr list --state merged --search "merged:>=${ISSUE_DATE%%T*}" \
    --json number,title,mergedAt

# Duplicate / superseding issues (open or closed).
gh issue list --state all --search "<key terms from the issue>" \
    --json number,title,state,closedAt
```

Explicitly check for: (a) work already merged that closes or partially closes the
issue, (b) design changes that make the original ask obsolete or misframed, (c)
duplicate or superseding issues. Then output one verdict, with the evidence
(commits, PRs, files, issue numbers) behind it:

| Verdict | Meaning |
|---------|---------|
| **Still needed** | Nothing since filing addresses it; proceed as written |
| **Partially addressed** | Some of the ask already landed; implement only the remainder (list what is left) |
| **No longer needed** | Already solved or made obsolete; recommend closing instead of implementing |
| **Needs reframing** | The surrounding design changed enough that the plan is wrong; restate the corrected approach |

**Section B depth floor (applies regardless of how concise the model is tuned to
be):** the evidence must enumerate what was actually inspected - the commit SHAs
(or an explicit `none touching <paths>`), the merged PR numbers, and the
duplicate/superseding issue numbers considered. A bare verdict, or evidence
summarized as "reviewed recent history", does not satisfy the gate.

**Section C - Proposed changes (pending approval).** An overview of the changes
proposed to close the issue, framed as a plan awaiting reviewer approval: files to
create or modify, the gist of each change, scope estimate, and notable risks or
edge cases. No code is written until this plan is approved.

**Section C depth floor:** every file to create or modify gets its own numbered
line with the gist of its change - never "various files" or a rolled-up
description - plus a scope estimate (files, approximate lines) and at least one
named risk, or an explicit "no notable risks".

### Step 3: The approval gate

The verdict drives what happens next:

- **No longer needed** -> do NOT implement, even with `--yes`. Recommend closing
  the issue and provide a ready-to-paste closing comment citing the evidence:
  ```bash
  gh issue close "$ISSUE_NUM" --comment "<evidence-based reason; reference the superseding PR/issue>"
  ```
  Surface the recommendation and STOP. Closing is the reviewer's call.
- **Still needed**, **Partially addressed**, or **Needs reframing** -> present
  Section C and gate on approval:
  - **Default (interactive):** pause and ask the reviewer to approve, redirect,
    or reject the plan. Only proceed once approved. For `Partially addressed` /
    `Needs reframing`, the approved plan is the adjusted one, not the original
    issue body.
  - **`--yes` / `--auto-approve`, or an `eli5: auto-approve` trailer in the issue
    body or HEAD commit message:** proceed without pausing, but still print the
    full report for the record and note that approval was auto-granted.

## Output format

```
ELI5 Gate: Issue #398

== A. What this issue actually wants (ELI5) ==
{plain-language intent, 2-4 sentences}

== B. Is it still needed? ==
Verdict: Still needed | Partially addressed | No longer needed | Needs reframing

Evidence (since {ISSUE_DATE}):
  - commits:  {sha list or "none touching <paths>"}
  - PRs:      {merged PR numbers or "none"}
  - dup/super:{issue numbers or "none"}
Reasoning: {1-3 sentences tying evidence to the verdict}

== C. Proposed changes (pending approval) ==
  1. {file} - {what changes and why}
  2. {file} - {what changes and why}
Scope: {N files, ~L lines}
Risks: {edge cases / unknowns}

Approval: REQUIRED (interactive) | AUTO-GRANTED (--yes) | N/A (No longer needed -> close recommended)
```

The template above is a floor, not a ceiling: fill every `{...}` slot with the
actual evidence, files, and reasoning - never elide or compress a slot away,
however terse the surrounding style. Reports below this density fail the gate.
<!-- eli5-core:end -->

## Integrating into your pipeline

Run this gate between "analyze the issue" and "write the code":

- Verdict **No longer needed** -> stop the pipeline and surface the close-issue
  recommendation instead of implementing.
- Verdicts **Still needed / Partially addressed / Needs reframing** -> pause for
  approval unless invoked with `--yes` (or an `eli5: auto-approve` trailer is
  present), then implement the APPROVED plan - which for `Partially addressed` /
  `Needs reframing` is the adjusted plan, not the original issue body.

Reference integration: claude-power-pack's `/flow:auto` runs this gate as Step 3
of its nine-step issue lifecycle (between Analyze and Implement).

## Notes

- This command is the communication and approval checkpoint: intent in the
  reviewer's language, an honest necessity verdict, and the plan that is about to
  be executed.
- It never writes implementation code; the only mutating action it suggests is
  `gh issue close` on a `No longer needed` verdict, and that is a recommendation
  for the reviewer to run.
- The staleness check is only meaningful when it inspects history *after* the
  issue's `createdAt`; always anchor `git log --since` and the PR/issue searches
  to that timestamp.
- The section between the `eli5-core:begin`/`eli5-core:end` markers is the
  canonical core that downstream vendors (e.g. claude-power-pack) sync against;
  edit it here, not in a vendored copy.
