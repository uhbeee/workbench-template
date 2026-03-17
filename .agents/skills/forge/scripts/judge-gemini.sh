#!/usr/bin/env bash
# Judge wrapper for Gemini CLI. Pipes plan artifacts to gemini -p with retry logic.
# Usage: ./judge-gemini.sh <plan-dir> <prompt-file>
# Returns: Text output from gemini, or exit code 1 on failure.

set -euo pipefail

PLAN_DIR="${1:?Usage: judge-gemini.sh <plan-dir> <prompt-file>}"
PROMPT_FILE="${2:?Usage: judge-gemini.sh <plan-dir> <prompt-file>}"
TIMEOUT="${FORGE_JUDGE_TIMEOUT:-60}"
MAX_RETRIES="${FORGE_JUDGE_RETRIES:-2}"

# Check gemini is installed
if ! command -v gemini &>/dev/null; then
    echo '{"error": "gemini CLI not found", "fallback": true}' >&2
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

# Retry loop
for attempt in $(seq 1 $MAX_RETRIES); do
    if output=$(timeout "$TIMEOUT" bash -c "cat '$CONTEXT_FILE' | gemini -p '$PROMPT'" 2>/dev/null); then
        if [ -n "$output" ]; then
            echo "$output"
            exit 0
        fi
    fi

    if [ "$attempt" -lt "$MAX_RETRIES" ]; then
        sleep $((attempt * 2))
    fi
done

echo '{"error": "gemini failed after retries", "fallback": true}' >&2
exit 1
