---
name: hunk-diff-review
description: Address review comments the user left in a live Hunk diff session - read their notes, reply to questions as inline Hunk notes, and make document changes ONLY where the user has explicitly approved them. Use when the user says /hunk-diff-review, or asks to address/respond to/work through the comments or notes they left in a Hunk diff.
---

# Hunk Diff Review

Work through the review comments a user left in a live Hunk diff and address each one -
**resolving most with a reply note, and changing the document only for edits the user has
explicitly approved.** This is the author side of a code review: you answer questions, you
propose fixes, and you apply a fix only after the reviewer says yes.

Agent-agnostic: it drives the `hunk` CLI over whatever repo the session is loaded on. No
dependency on workbench `context/` or `config.yaml`.

## Iron rules (these are the whole point of this skill)

1. **Do NOT auto-edit the document in response to comments.** Most review comments are
   questions or clarifications - they are resolved by a **reply**, not a doc change. Editing
   the doc to "answer" a question is wasteful and, worse, invalidates the review the user is
   in the middle of.
2. **A comment that does warrant a change must be PROPOSED and APPROVED before you touch the
   file.** Post the exact change you intend as a note (or in chat) marked
   `PROPOSED CHANGE (approve?)`, then wait. Never batch-apply edits across a review.
3. **Never force a review restart.** If you make significant unrequested edits, the reviewer
   has to re-read the whole document from the top. Preserve their in-progress review: don't
   rewrite, reorder, or reload content under them without cause. When you do apply an approved
   edit, tell them, and reload the diff after.
4. **Replies live as Hunk notes** anchored to the same line as the user's comment (unless the
   user asks for chat instead). That keeps the conversation inline in their review.
5. **No git state changes without explicit sign-off.** Do not `commit`, `reset`, `restore`, or
   `rebase` to set up or clean up the review. If you need to (e.g. revert your own premature
   edits so the review is preserved), propose it and wait for approval.
6. **Apply all approved changes in one batch, at the very end.** Do NOT edit the document while
   the review is still open. Wait until the user has closed out **every** comment/thread -
   approved, denied, or closed - then apply all the approved changes together in a single pass
   and reload the diff once. Editing mid-review shifts lines under the reviewer and forces
   re-reading; batching at the end keeps their read stable and makes the applied set easy to see
   at once. Track each thread's disposition (approved / denied / closed) so you know when the
   review is fully resolved and exactly which changes to apply.

## Prerequisite: load the Hunk CLI skill

This skill drives Hunk through its `hunk session *` CLI. If the `hunk-review` skill
instructions are not already in context, load them first:

```bash
hunk skill path      # prints the path to hunk-review/SKILL.md
```

Read the file it prints. It is the source of truth for the CLI (session list/get/review/
navigate/reload, and `comment add|apply|list|rm|clear`). Do not author Hunk commands from
memory. Remember its rule: **the TUI belongs to the user - never run `hunk diff`/`hunk show`
directly; use `hunk session *` against the live daemon.** (If `hunk` is not installed, tell the
user; it is a prerequisite for this skill.)

## Workflow

1. **Find the session.** `hunk session list --json`.
   - No session → ask the user to launch Hunk in their terminal (or `hunk diff` / `hunk diff HEAD`).
   - Multiple sessions match the repo → target by `<session-id>`, not `--repo` (avoids
     "Multiple active sessions match").
2. **Make sure the diff shows what the user is reviewing.** `hunk session review <id> --json`
   (structure only; add `--include-patch` only for files you must read raw).
   - **Staged-vs-unstaged gotcha:** plain `hunk diff` shows only *unstaged* changes. If the
     user's changes are **staged** (e.g. after a `git reset --soft`), the plain view is empty -
     reload against HEAD: `hunk session reload <id> -- diff HEAD`. Confirm the file list matches
     what they expect before proceeding.
3. **Read the user's comments.** `hunk session comment list <id> --type user --json`. Each note
   has `filePath`, `newRange`/`oldRange` (line), and `body`.
4. **Triage every comment** into exactly one bucket (see Triage guide):
   - **Reply** - answer it with a note. No doc change.
   - **Propose** - it needs a doc change; write the specific change as a `PROPOSED CHANGE
     (approve?)` note and wait.
5. **Post the replies + proposals** as Hunk notes, anchored to each comment's line. Batch them
   in one `comment apply --stdin` call (it validates the whole batch before mutating):
   ```bash
   cat replies.json | hunk session comment apply <id> --stdin --json
   ```
   Each item needs `filePath`, `summary` (the note body - a real sentence), and exactly one
   target (`newLine` or `oldLine`); `author` and `rationale` are optional. Omit `--focus` so you
   don't yank the user's view.
6. **Report the triage** back to the user: which comments were answered (resolve on read) and
   which are proposals awaiting approval. Ask them to approve however they like (reply on the
   Hunk note, or in chat - e.g. "do 61 and 70, skip 38").
7. **Apply approved changes only after the whole review is resolved - all at once.** Do not edit
   mid-review. Once the user has closed out every thread (approved / denied / closed), apply all
   the approved changes in a single batch, then `hunk session reload <id> -- diff HEAD` once so
   the user sees the final result. Leave everything not-approved untouched. Do not stage or
   commit unless the user tells you to.

## Triage guide - reply vs propose

**Reply (no doc change) — the default.** The comment is a question, asks for an explanation, or
is satisfied by information you can give:
- "what is X?", "explain this", "why did we decide Y?", "does this mean Z?"
- Answer it in the note. Only offer a doc change if the *document itself* is genuinely deficient
  (e.g. undefined jargon it relies on repeatedly) - and even then, offer it as a proposal, don't
  apply it.

**Propose (await approval).** The comment explicitly requests a change, or the doc is wrong/
misleading and must change:
- "add X to the plan", "reword this", "this shouldn't be here", "remove Y".
- Write the concrete change (what text, where) in a `PROPOSED CHANGE (approve?)` note. Keep the
  proposal specific enough that "yes" is enough to act on. Apply only after explicit approval.

When unsure, default to **reply** and ask whether they want a change. Erring toward a reply is
cheap; erring toward an edit costs them a review restart.

## Command quick-reference

```bash
hunk skill path                                        # locate + load the CLI skill
hunk session list --json                               # find sessions (target multi by id)
hunk session review <id> --json                        # file/hunk structure
hunk session reload <id> -- diff HEAD                  # load staged changes (see gotcha)
hunk session comment list <id> --type user --json      # read the user's notes
cat replies.json | hunk session comment apply <id> --stdin --json   # batch reply/propose notes
hunk session comment add <id> --file <f> --new-line <n> --summary "..."   # one note
hunk session comment rm <id> <comment-id>              # remove one of YOUR notes (no in-place edit)
```

Reply-batch JSON shape:

```json
{ "comments": [
  { "filePath": "path/to/file", "newLine": 61, "author": "agent",
    "summary": "Reply: <answer>."  },
  { "filePath": "path/to/file", "newLine": 70, "author": "agent",
    "summary": "PROPOSED CHANGE (approve?): <exact change>."  }
] }
```

Notes: you can add/remove your **own** notes but cannot edit the **user's** notes - respond
alongside them. `comment apply` reads the batch only from stdin. Anchors are 1-based; use
`newLine` for added/context lines on the new side, `oldLine` for removed lines.

## Done

Summarize what was answered vs. what awaits approval, and stop. Do not proceed to edits or
commits on your own - the reviewer drives.
