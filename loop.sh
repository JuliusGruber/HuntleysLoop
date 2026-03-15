#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-build}"          # "plan", "build", or "specs"
MAX_ITERS="${2:-0}"         # 0 = infinite
PROMPT_FILE="PROMPT_${MODE}.md"
ITER=0

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: $PROMPT_FILE not found"
  exit 1
fi

while :; do
  ITER=$((ITER + 1))
  echo "=== Iteration $ITER (mode: $MODE) ==="

  cat "$PROMPT_FILE" | claude -p \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --model opus \
    --verbose

  # Push after each iteration so work isn't only local
  git push 2>/dev/null || true

  if [ "$MAX_ITERS" -gt 0 ] && [ "$ITER" -ge "$MAX_ITERS" ]; then
    echo "Reached max iterations ($MAX_ITERS). Stopping."
    break
  fi
done
