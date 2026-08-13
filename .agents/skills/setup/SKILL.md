---
name: setup
description: Run one-command workbench setup. Creates junctions, configures shell profile, sets up global skills.
---

# Setup

Run the interactive setup for the workbench environment.

## Instructions

1. Run `bash scripts/setup.sh` to start setup
2. The script handles:
   - Platform detection
   - Config bootstrap (creates config.yaml from template if needed)
   - Junction and symlink creation
   - Shell profile configuration
   - Global skills setup
   - Context directory creation
   - Verification (runs doctor)
3. If any step fails, explain the issue and suggest remediation
4. On Windows, if the CLAUDE.md file symlink fails (requires admin), provide the exact PowerShell command to run in an admin terminal

## Selecting Which Skills to Install

If the user wants only a subset of the global skills on this machine:

1. Read the catalog: the `global:` list in `skills-global.yaml`
2. Ask which skills to install (multi-select; offer "everything" as the default)
3. Write the selection to `skills-local.yaml` (gitignored) as an `only:` list —
   or an `exclude:` list if they named what to drop (see skills-local.example.yaml)
4. Run `bash scripts/setup-global-skills.sh` — deselected skills' links are
   pruned, selected ones are created
5. To go back to everything: delete skills-local.yaml and re-run

## Example Invocation

User: /setup
Agent: Runs scripts/setup.sh, monitors output, helps resolve any issues
