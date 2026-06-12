---
name: calendar-sync
description: Read Outlook Web calendar via Chrome and extract meeting data for capacity planning. Writes to context/active/calendar.md so other skills use real numbers.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Calendar Sync

Read the Outlook Web calendar in Chrome and extract meeting data so the capacity model uses real numbers, not guesses.

## Process

### Step 1: Open Outlook Calendar

Use `mcp__claude-in-chrome__tabs_context_mcp` to check if Outlook is already open.

- If Outlook calendar is open in a tab, use that tab.
- If not, use `mcp__claude-in-chrome__tabs_create_mcp` to open `https://outlook.office.com/calendar/view/workweek` (work week view).

### Step 2: Read This Week's Meetings

Use `mcp__claude-in-chrome__read_page` or `mcp__claude-in-chrome__get_page_text` to extract the calendar content.

If the calendar view doesn't render readable text, use `mcp__claude-in-chrome__javascript_tool` to extract meeting data from the DOM. Outlook Web typically renders meetings with:
- Meeting title
- Start/end time
- Duration
- Attendees (sometimes)

If that doesn't work, use `mcp__claude-in-chrome__read_page` to get a screenshot and parse it visually.

### Step 3: Navigate to Specific Days if Needed

If the user asks for a specific day or the current view doesn't show the full week:
- Use `mcp__claude-in-chrome__navigate` to go to the appropriate calendar view

### Step 4: Parse and Structure Meeting Data

Organize the extracted meetings:

```
## Calendar — Week of YYYY-MM-DD

### Monday
| Time | Meeting | Duration |
|------|---------|----------|
| 9:00-9:30 | Standup | 0.5h |
| 10:00-11:00 | Design Review | 1h |
| **Total meeting hours** | | **1.5h** |
| **Available productive hours** | | **4.5-5.5h** |

### Weekly Summary
| Day | Meetings (h) | Available (h) |
|-----|-------------|---------------|
| Mon | 1.5 | 4.5-5.5 |
| ... | ... | ... |
| **Total** | **X** | **Y** |
```

### Step 5: Write Calendar File

Save the parsed calendar to `context/active/calendar.md`.

This file is read by `/weekly-plan` and `/morning-triage` to calculate real capacity.

### Step 6: Flag Concerning Patterns

After parsing, flag:
- **Heavy meeting days** (4h+): "Thursday has only 2-3h of productive time."
- **Back-to-back blocks**: "Tuesday 9-12 is solid meetings. No productive work until afternoon."
- **Meeting-free blocks**: "Wednesday morning is clear — best slot for deep focus work."
- **Overall meeting load**: If meetings exceed 12h/week, flag it.

## Important Notes

- This skill requires Outlook Web to be accessible in Chrome. If not logged in, ask the user to log in first.
- Calendar data is a snapshot — suggest re-syncing if the user mentions a new meeting.
- Respect privacy: only extract meeting titles, times, and durations. Don't extract attendee lists or meeting bodies unless specifically asked.
