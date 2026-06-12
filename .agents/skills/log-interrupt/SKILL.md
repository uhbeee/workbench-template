---
name: log-interrupt
description: Quickly log an interrupt to today's daily plan with a timestamp. Faster than the full interrupt agent for minor disruptions. Pass a brief description as the argument.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Log an Interrupt

Quickly log an interrupt to today's daily plan. Faster than the full interrupt agent for minor disruptions.

**Argument**: Description of the interrupt (required)

## Process

1. Read `context/active/daily.md`
2. If the file doesn't exist, tell the user to run morning-triage first
3. Find the `## Interrupts` section
4. Append a new line with the current timestamp and the user's description:
   ```
   - [HH:MM] Interrupt: <description> [est: ?h, actual: ?h]
   ```
5. Update the `## Capacity Today` section: reduce remaining hours by 0.25h (minimum interrupt cost)
6. Save the file

## Output

Confirm the interrupt was logged. Show updated remaining capacity.
