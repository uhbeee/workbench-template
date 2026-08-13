---
name: add-skill
description: Import skills from a GitHub repo/URL, local path, or the built-in registry into the workbench, with provenance tracking and global or project scope.
---

# Skill Import

Import skills into `.agents/skills/` — the single source of truth delivered to
every harness (Claude Code, Codex, Cursor, ... per `skill-targets.yaml`).
Remote imports are recorded in `skills-lock.yaml` so `/update-skill` can pull
upstream changes later.

## Instructions

The user provides one of:
- A **repo URL** (e.g., `https://github.com/mattpocock/skills`) — contains many skills
- A **skill URL** (e.g., `https://github.com/user/repo/tree/main/skills/commit`) — one skill
- A **local path**
- A **registry name** (see `bash scripts/skill-add.sh --list`)

Scope is **global by default** (registered in `skills-global.yaml` + linked
into every target dir). Pass `--project` if the user wants it only in this repo.

### Single skill (skill URL, local path, or registry name)

1. Run `bash scripts/skill-add.sh <source>` (add `--project` or `--force` as needed)
2. Confirm installation and show the skill's description

### Whole repo (repo URL, or URL to a directory of skills)

1. Enumerate: `bash scripts/skill-add.sh <url> --list-skills`
2. Present the list to the user and ask which to import (multi-select).
   If they already said "all", skip the question.
3. Install the selection:
   `bash scripts/skill-add.sh <url> --skills name1,name2` (or `--all`)

### After any import

- Confirm what was installed and at what scope
- Ask: "Add to template allowlist? [y/n/private]"
  - y: Add `.agents/skills/<name>/` to scripts/template-allowlist.yaml
  - n: Skip
  - private: Note that it's intentionally private (for documentation)
- Remind the user that other machines pick this up via `git pull` +
  `bash scripts/setup-global-skills.sh`

## Example Invocations

- `/add-skill https://github.com/mattpocock/skills` — enumerate repo, pick skills
- `/add-skill https://github.com/anthropics/skills/tree/main/skills/commit` — one skill
- `/add-skill commit` — from registry
- `/add-skill /path/to/skill --project` — local path, this repo only

## Related

- `/update-skill` — pull upstream changes for imported skills
- `skill-targets.yaml` — which harness directories receive links
- `skills-lock.yaml` — provenance (repo, branch, path, ref) per import
