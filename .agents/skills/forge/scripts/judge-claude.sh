#!/usr/bin/env bash
# Judge wrapper for Claude (same-model fallback). Uses claude CLI in non-interactive mode.
# Usage: ./judge-claude.sh <plan-dir> <prompt-file>
# Returns: Text output from claude, or exit code 1 on failure.
#
# This is the Tier 2 fallback when Codex/Gemini CLIs are unavailable.
# Same-model bias risk, but never blocked.

set -euo pipefail

PLAN_DIR="${1:?Usage: judge-claude.sh <plan-dir> <prompt-file>}"
PROMPT_FILE="${2:?Usage: judge-claude.sh <plan-dir> <prompt-file>}"
TIMEOUT="${FORGE_JUDGE_TIMEOUT:-90}"

# Check claude is available
if ! command -v claude &>/dev/null; then
    echo '{"error": "claude CLI not found", "fallback": false}' >&2
    exit 1
fi

# Assemble context
CONTEXT_FILE=$(mktemp)
trap 'rm -f "$CONTEXT_FILE"' EXIT

for artifact in research.md analysis.md plan.md; do
    artifact_path="$PLAN_DIR/$artifact"
    if [ -f "$artifact_path" ]; then
        echo "--- $artifact ---" >> "$CONTEXT_FILE"
        cat "$artifact_path" >> "$CONTEXT_FILE"
        echo "" >> "$CONTEXT_FILE"
    fi
done

PROMPT=$(cat "$PROMPT_FILE")
FULL_PROMPT="$PROMPT

$(cat "$CONTEXT_FILE")"

# Claude CLI uses -p for non-interactive prompt
if output=$(timeout "$TIMEOUT" claude -p "$FULL_PROMPT" --model sonnet 2>/dev/null); then
    if [ -n "$output" ]; then
        echo "$output"
        exit 0
    fi
fi

echo '{"error": "claude judge failed", "fallback": false}' >&2
exit 1
