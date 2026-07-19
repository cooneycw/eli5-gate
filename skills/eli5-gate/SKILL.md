---
name: eli5-gate
description: Pre-implementation necessity gate for GitHub issues. Use BEFORE implementing any GitHub issue - restates the issue's intent in plain language (ELI5), checks whether the issue is still worth doing given everything merged since it was filed (Still needed / Partially addressed / No longer needed / Needs reframing), and presents the proposed changes for reviewer approval before any code is written. Invoke when asked to gate, sanity-check, or triage an issue, or as the checkpoint between analyzing an issue and implementing it.
license: MIT
metadata:
  author: cooneycw
  homepage: https://github.com/cooneycw/eli5-gate
---

# ELI5 Necessity Gate

Most issue-to-PR automation asks "how do we implement this?" This gate asks the
more valuable question first: "should this issue exist at all?"

This skill is read-only with respect to the codebase: it inspects and reports, it
does not write implementation code. It requires the `gh` CLI, authenticated,
run from inside the git repository the issue belongs to.

## Routine

The full canonical routine lives in [commands/eli5.md](../../commands/eli5.md) at
the repository root (the section between the `eli5-core` markers). If that file is
not available in your installation, follow the condensed routine below - it is the
same procedure.

### Step 1: Gather context

```bash
gh issue view "$ISSUE_NUM" --json number,title,state,body,createdAt,labels,closedAt
ISSUE_DATE=$(gh issue view "$ISSUE_NUM" --json createdAt --jq '.createdAt')
```

Parse acceptance criteria (`- [ ]` items) and referenced files; read those files
so the proposed-changes section is concrete. If a larger pipeline already analyzed
the issue, reuse that analysis.

### Step 2: Produce the three-section report (all three, every time)

**A. ELI5 overview of intent** - plain-language restatement of what the issue is
trying to accomplish and why, 2-4 sentences minimum (a short paragraph is fine) a
non-author reviewer can sanity-check for a misread.

Depth floor: motivation before mechanics - what is wrong today and why it matters,
*before* what will change; every unavoidable technical term gets a plain-language
gloss on first use ("the worktree (a scratch copy of the repo)"); and someone who
has never seen this codebase must finish the section understanding what is wrong
now and what will be better after. A restatement of the issue title, or sentences
that only parse for a reader who already read the issue, does not satisfy the gate.

**B. Necessity / staleness analysis** - anchor to the issue's `createdAt` and
inspect post-filing history:

```bash
git log --since="$ISSUE_DATE" --oneline -- <relevant/paths>
gh pr list --state merged --search "merged:>=${ISSUE_DATE%%T*}" --json number,title,mergedAt
gh issue list --state all --search "<key terms>" --json number,title,state,closedAt
```

Check for (a) work already merged that closes or partially closes the issue,
(b) design changes that obsolete or misframe the ask, (c) duplicate/superseding
issues. Output ONE verdict with the evidence behind it:

| Verdict | Meaning |
|---------|---------|
| Still needed | Nothing since filing addresses it; proceed as written |
| Partially addressed | Some already landed; implement only the remainder |
| No longer needed | Solved or obsolete; recommend closing instead of implementing |
| Needs reframing | The design moved; restate the corrected approach |

Depth floor: the evidence must name the actual commit SHAs, merged PR numbers, and
duplicate/superseding issue numbers inspected (or an explicit "none") - a bare
verdict, or "reviewed recent history", does not satisfy the gate.

**C. Proposed changes (pending approval)** - files to create/modify, gist of each
change, scope estimate, risks. No code until approved. Depth floor: one numbered
line per file with its change gist - never "various files" - plus a scope estimate
and at least one named risk (or an explicit "no notable risks").

### Step 3: The approval gate

- **No longer needed** -> do NOT implement, even in unattended mode. Provide a
  ready-to-paste `gh issue close --comment` citing the evidence; closing is the
  reviewer's call. STOP.
- **Other verdicts** -> pause for reviewer approval (approve / redirect / reject).
  In unattended mode (`--yes` / `--auto-approve`, or an `eli5: auto-approve`
  trailer in the issue body or HEAD commit), proceed but print the full report
  and note auto-approval.
  For `Partially addressed` / `Needs reframing`, the approved plan is the
  ADJUSTED one, not the original issue body.

## Output format

```
ELI5 Gate: Issue #N

== A. What this issue actually wants (ELI5) ==
Wrong-today + why it matters, then what gets better; jargon glossed on first use
== B. Is it still needed? ==
Verdict + evidence (commits / PRs / dup-super issues since createdAt) + reasoning
== C. Proposed changes (pending approval) ==
Numbered file-level plan + scope + risks
Approval: REQUIRED | AUTO-GRANTED | N/A (close recommended)
```

The skeleton is a floor, not a ceiling: fill every slot with the actual evidence
and files, regardless of how concise the model's surrounding style is.
