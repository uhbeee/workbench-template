---
name: update-skill
description: Pull upstream changes for skills imported via add-skill, using the provenance recorded in skills-lock.yaml. Shows diffs before overwriting local modifications.
---

# Skill Update

Update imported skills from their source repos, tracked in `skills-lock.yaml`.

## Instructions

1. Run `bash scripts/skill-update.sh` (or `bash scripts/skill-update.sh <name>`
   for specific skills).
2. Report the summary: updated / up to date / skipped / failed.
3. For each skill reported as **locally modified AND upstream changed**:
   - Show the user the diff the script printed
   - Ask whether to keep the local version or take upstream
   - If they choose upstream: `bash scripts/skill-update.sh <name> --force`
4. If any skill is "in lock file but not installed", offer to reinstall it
   via `/add-skill`.

## Notes

- Only skills imported from GitHub are updatable; local-path imports are skipped.
- A successful update bumps the `ref` in `skills-lock.yaml` — commit that change.
- Updates modify `.agents/skills/` directly; every harness sees the change
  immediately through its links.

## Example Invocations

- `/update-skill` — check all tracked skills
- `/update-skill ts-reset` — check one skill
