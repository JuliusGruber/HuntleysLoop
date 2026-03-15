#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-build}"                    # "plan", "build", or "specs"
MAX_ITERS="${2:-0}"                   # 0 = infinite
MODEL="${RALPH_MODEL:-opus}"          # override with RALPH_MODEL env var
PROMPT_FILE="$SCRIPT_DIR/PROMPT_${MODE}.md"
ITER=0

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: $PROMPT_FILE not found"
  exit 1
fi

while :; do
  ITER=$((ITER + 1))
  echo "=== Iteration $ITER (mode: $MODE, model: $MODEL) ==="

  cat "$PROMPT_FILE" | claude -p \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --model "$MODEL" \
    --verbose

  # Push after each iteration so work isn't only local
  git push 2>/dev/null || true

  if [ "$MAX_ITERS" -gt 0 ] && [ "$ITER" -ge "$MAX_ITERS" ]; then
    echo "Reached max iterations ($MAX_ITERS). Stopping."
    break
  fi
done
