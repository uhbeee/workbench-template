#!/usr/bin/env bash
# Judge wrapper for Codex CLI. Pipes plan artifacts to codex exec with retry logic.
# Usage: ./judge-codex.sh <plan-dir> <prompt-file>
# Returns: JSON output from codex, or exit code 1 on failure.

set -euo pipefail

PLAN_DIR="${1:?Usage: judge-codex.sh <plan-dir> <prompt-file>}"
PROMPT_FILE="${2:?Usage: judge-codex.sh <plan-dir> <prompt-file>}"
TIMEOUT="${FORGE_JUDGE_TIMEOUT:-60}"
MAX_RETRIES="${FORGE_JUDGE_RETRIES:-2}"

# Check codex is installed
if ! command -v codex &>/dev/null; then
    echo '{"error": "codex CLI not found", "fallback": true}' >&2
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
    if output=$(timeout "$TIMEOUT" codex exec --json "$PROMPT" < "$CONTEXT_FILE" 2>/dev/null); then
        # Extract the last turn.completed message from JSONL
        result=$(echo "$output" | grep -o '.*' | python3 -c "
import sys, json
lines = sys.stdin.read().strip().split('\n')
for line in reversed(lines):
    try:
        obj = json.loads(line)
        if obj.get('type') == 'turn.completed':
            # Extract text from the response
            for item in obj.get('turn', {}).get('items', []):
                if item.get('type') == 'text':
                    print(item.get('text', ''))
                    sys.exit(0)
    except json.JSONDecodeError:
        continue
# Fallback: print raw output
print(lines[-1] if lines else '')
" 2>/dev/null)

        if [ -n "$result" ]; then
            echo "$result"
            exit 0
        fi
    fi

    if [ "$attempt" -lt "$MAX_RETRIES" ]; then
        sleep $((attempt * 2))
    fi
done

echo '{"error": "codex failed after retries", "fallback": true}' >&2
exit 1
