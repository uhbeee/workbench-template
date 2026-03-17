---
name: add-skill
description: Import a skill from GitHub URL, local path, or the built-in registry.
---

# Skill Import

Import a skill into the workbench from various sources.

## Instructions

The user will provide one of:
- A GitHub URL (e.g., `https://github.com/user/repo/tree/main/.claude/skills/commit`)
- A local filesystem path
- A skill name from the registry

1. Determine the source type from the argument
2. Run `bash scripts/skill-add.sh <source>` with appropriate flags
3. If the user wants it globally available, add `--global`
4. If replacing an existing skill, add `--force`
5. After import, confirm the skill was installed and show its description
6. Ask: "Add to template allowlist? [y/n/private]"
   - y: Add the skill path to scripts/template-allowlist.yaml
   - n: Skip
   - private: Note that it's intentionally private (for documentation)

## Listing Available Skills

If the user asks what's available, run `bash scripts/skill-add.sh --list` to show the registry.

## Example Invocations

- `/add-skill commit` — Import "commit" skill from registry
- `/add-skill https://github.com/anthropics/skills/tree/main/.claude/skills/commit` — Import from GitHub
- `/add-skill /path/to/skill --global` — Import from local path and make global
