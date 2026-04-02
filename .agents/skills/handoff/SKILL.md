---
name: handoff
description: Write or update a handoff document so the next agent with fresh context can continue this work. Use when approaching context limits.
argument-hint: [optional-folder-path]
---

# Handoff

Write or update a handoff document so the next agent with fresh context can continue this work.

## Workflow

1. Determine where to write the handoff document:
   - If the user provides a folder path, use it.
   - If a plan folder is being worked on in the current session (e.g., via `/plan-implement`), use that plan folder.
   - Otherwise, write `HANDOFF.md` to the project root.

2. Read existing context from the target folder:
   - `HANDOFF.md` - prior handoff context if it exists (read before overwriting)
   - If in a plan folder, also read `plan.md`, `research.md` and `pr-breakdown.md` if they exist.

3. Create or update `HANDOFF.md` in the target folder with these sections:

   - **Goal**: What we're trying to accomplish.
   - **Context**: Where relevant files live. If working within a plan, include paths to `plan.md` and `pr-breakdown.md`.
   - **Current Progress**: What's been done so far in this session and prior sessions. Include files created/modified, and if plan-based, which PRs are completed vs in progress.
   - **Current Branch**: The git branch being worked on.
   - **What Worked**: Approaches and patterns that succeeded (e.g., specific test patterns, mocking strategies, API patterns discovered).
   - **What Didn't Work**: Approaches that failed so they're not repeated.
   - **Open Questions**: Any unresolved decisions or ambiguities.
   - **Next Steps**: Clear, actionable items for continuing. Be specific about what file to edit, what method to implement, what test to write next.

4. Tell the user:
   - The file path of the handoff document
   - To start a fresh conversation
   - To begin the new conversation with: `Read <path-to-HANDOFF.md> and continue the work`
