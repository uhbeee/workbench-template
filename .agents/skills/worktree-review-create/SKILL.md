---
name: worktree-review-create
description: Create or refresh a managed review worktree for a GitHub PR or branch using canonical Python worktree tooling, then prepare a reviewer-ready HTML packet when the user wants code reviewed. Use when the user asks to review a PR locally, create a PR review checkout, run wt-review, inspect another branch in an isolated review worktree, or help a reviewer/agent understand what changed and where to focus.
compatibility: macOS or Windows Workbench setup with Git and Python 3. GitHub PR lookup is better with gh. Uses scripts/wt_review.py, a symlink to the canonical Workbench script.
metadata:
  workbench.argument-hint: "<PR#|PR URL|branch> [--repo name] [--dry-run]"
---

# Create Review Worktree

Create or refresh `_review/current` for a PR number, PR URL, or remote branch. For actual PR review work, also create a `reviewer-packet.html` that helps the reviewer inspect the diff with the right context, risks, file tour, validation evidence, and reviewer-agent prompt.

Use the skill-local script symlink:

```bash
python3 scripts/wt_review.py <PR#|PR URL|branch> [--repo <repo>] [--dry-run]
```

On Windows, use:

```powershell
py -3 scripts\wt_review.py <PR#|PR URL|branch> [--repo <repo>] [--dry-run]
```

## Process

1. Parse the PR number, PR URL, or branch name.
2. If the repo is not obvious from the current workdir, pass `--repo`.
3. Run the script. It refreshes `_review/current`, fetches the PR or branch, creates the review worktree, and syncs local AI-tool config into the worktree.
4. Report `WORKTREE_PATH` and `BRANCH`.
5. Use that path as the `workdir` for subsequent review commands.
6. If the request is to review code, help a reviewer, or inspect a PR rather than only create a checkout, generate the reviewer packet described below.

If the user explicitly asks only for the checkout, stop after reporting `WORKTREE_PATH`, `BRANCH`, and the command to enter the review worktree.

## Reviewer Packet

Create or update `reviewer-packet.html` in the review worktree when the user asks to review a PR, prepare a review, hand work to another reviewer, or make an agent-reviewable checkout. For PR-number or PR-URL inputs, this is the default. For branch-only inputs, create the packet if a base branch can be inferred; otherwise label PR metadata as unavailable.

Use the inactive `write-html` PR/code-review reference when it is available:

- Read the routing reference at `<workbench-root>/.agents/inactive-skills/write-html/references/html-artifact-patterns.md`.
- Load the focused reference `<workbench-root>/.agents/inactive-skills/write-html/references/03-code-review-pr.md`.
- Use `<workbench-root>/.agents/inactive-skills/write-html/assets/03-code-review-pr.html` as the starter template when useful.
- For Workbench reviewer packets, also read `<workbench-root>/context/standards/html-plan-standard.md`.

Gather review anchors before writing:

```bash
gh pr view <PR#> --json title,url,author,baseRefName,headRefName,body,files,commits,additions,deletions,reviewDecision,statusCheckRollup
git -C "$WORKTREE_PATH" diff --stat origin/<base>...HEAD
git -C "$WORKTREE_PATH" diff --name-status origin/<base>...HEAD
git -C "$WORKTREE_PATH" diff --check origin/<base>...HEAD
```

Use local `git` output when `gh` is unavailable. Do not block packet creation only because GitHub metadata is missing; state the missing metadata and continue with branch, diff, and file anchors.

The packet must include:

- top summary: PR or branch, base/head, author when known, files changed, additions/deletions, current review status, primary risk, and next review action,
- what changed and why,
- before/after behavior,
- file-by-file tour with "why this file matters",
- risk map by file, subsystem, or contract,
- annotated diff snippets only for risky changes or contract-defining lines,
- reviewer focus checklist,
- validation evidence and validation gaps,
- rollout and rollback notes when relevant,
- source anchors, assumptions, and missing context,
- exact reviewer-agent prompt.

Use this prompt shape inside the packet and tailor the placeholders:

```text
You are reviewing <PR or branch> in <WORKTREE_PATH>. Read reviewer-packet.html first, then inspect the diff against origin/<base>. Prioritize correctness, regression risk, missing tests, security/privacy/auth, and contract compatibility. Report findings first with file/line references, then note residual test gaps.
```

After writing the packet, validate it:

```bash
python3 <workbench-root>/.agents/inactive-skills/write-html/scripts/validate_html.py "$WORKTREE_PATH/reviewer-packet.html"
```

Open it in a browser for a visual pass when practical, especially if the packet includes diagrams, copied prompts, or code blocks.

## Guardrails

- This skill owns `_review/current`; creating a new review worktree replaces the previous current review checkout.
- Do not use it for implementation work. Use `worktree-feature-create` for code changes.
- If the review worktree has important dirty work, stop and ask before replacing it.
- The reviewer packet is a navigation aid, not a substitute for inspecting the diff. Do not hide risky files behind a summary.
- Keep annotated snippets short. Do not paste the entire PR diff into the HTML.
- Review findings need file and line references whenever possible.
- If PR metadata, linked ticket, checks, or base branch are unavailable, label that as missing context rather than guessing.
