# Ralph Loop Implementation Plan

## Overview

Implement the simplest possible autonomous coding agent using the "Ralph Wiggum" pattern — a bash while loop that repeatedly feeds a prompt to Claude CLI in headless mode. Each iteration picks one task, implements it, runs tests, commits, and exits with a fresh context window. `IMPLEMENTATION_PLAN.md` on disk is the shared state between iterations.

---

## Minimal File Tree

```
HuntleysLoop/
├── loop.sh                    # The bash while loop (the "orchestrator")
├── PROMPT_plan.md             # Planning mode prompt
├── PROMPT_build.md            # Building mode prompt
├── AGENTS.md                  # Operational guide (build/test commands, patterns)
├── IMPLEMENTATION_PLAN.md     # Shared state between iterations (starts empty)
├── specs/                     # Requirements (one file per concern)
│   └── [your-feature].md      # e.g., specs/core-functionality.md
├── src/                       # Application source code (built by Ralph)
│   └── lib/                   # Shared utilities (Ralph's "standard library")
└── .gitignore
```

---

## Files to Create

### 1. `loop.sh` — The Loop (~20 lines)

The entire orchestrator. Supports `plan` and `build` modes via argument.

```bash
#!/usr/bin/env bash
MODE="${1:-build}"  # "plan" or "build"
PROMPT_FILE="PROMPT_${MODE}.md"

while :; do
  cat "$PROMPT_FILE" | claude -p \
    --dangerously-skip-permissions \
    --model opus \
    --verbose
done
```

### 2. `PROMPT_plan.md` — Planning Mode Prompt

Instructs Claude to:
- Study `specs/*` to learn requirements
- Study existing `src/` code
- Do gap analysis (what's built vs. what's specified)
- Output a prioritized TODO list into `IMPLEMENTATION_PLAN.md`
- **Do NOT implement anything** — plan only

### 3. `PROMPT_build.md` — Building Mode Prompt

Instructs Claude to:
- Read `specs/*` and `IMPLEMENTATION_PLAN.md`
- Pick the most important unfinished task
- Search the codebase before assuming anything is missing
- Implement it, run tests
- Update `IMPLEMENTATION_PLAN.md` (mark done, note discoveries)
- Update `AGENTS.md` with operational learnings
- `git commit` and exit

Key guardrails baked into the prompt:
- "don't assume not implemented" — search first
- "only 1 subagent for build/tests" — backpressure
- "no placeholders or stubs" — implement completely
- "resolve bugs or document them" — even if unrelated

### 4. `AGENTS.md` — Operational Guide

Loaded every iteration as deterministic context. Contains:
- **Build & Run** — how to build the project
- **Validation** — test, typecheck, lint commands
- **Operational Notes** — learnings the agent discovers (self-updating)
- **Codebase Patterns** — conventions to follow

### 5. `IMPLEMENTATION_PLAN.md` — Shared State

Starts as an empty file. Planning loop populates it. Build loop reads and updates it. This is the only coordination mechanism between loop iterations.

### 6. `specs/` Directory

One spec file per feature/concern. Each file describes ONE topic of concern (scoped to "describable in one sentence without 'and'").

### 7. `.gitignore`

Standard ignores for the project.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Orchestration | Bash `while` loop | No framework needed. The loop IS the agent. |
| State management | `IMPLEMENTATION_PLAN.md` on disk | Survives context resets. Human-readable. |
| Context loading | `cat PROMPT.md \| claude -p` | Deterministic — same files loaded every time. |
| Backpressure | Tests + typecheck + lint in `AGENTS.md` | Rejects bad work automatically. |
| Task granularity | 1 task per iteration | Keeps context usage in the "smart zone" (40-60%). |
| Self-correction | Loop iterations | Wrong? Next iteration reads updated plan and fixes it. |
| Permissions | `--dangerously-skip-permissions` | Required for autonomy — run in a sandbox! |

---

## Critical Principles

1. **You sit OUTSIDE the loop**, not inside it. Your job is tuning guardrails, specs, and `AGENTS.md` — not coding.
2. **Fresh context every iteration** is a feature, not a bug. Prevents context pollution and keeps the agent in the "smart zone."
3. **The plan is disposable.** Wrong plan? Re-run planning mode. Cheap (1-2 iterations).
4. **"Don't assume not implemented"** — the single most important guardrail. Without it, the agent rewrites existing code.
5. **Run in a sandbox.** Docker, Fly Sprites, E2B — anything isolated. The agent has full permissions.

---

## Implementation Order

1. Decide what you want the agent to build (the JTBD / project goal)
2. Write 1-3 spec files in `specs/`
3. Fill in `AGENTS.md` with build/test commands
4. Create `PROMPT_plan.md` and `PROMPT_build.md`
5. Create `loop.sh`
6. Run `bash loop.sh plan` to generate the implementation plan
7. Review the plan, adjust specs if needed
8. Run `bash loop.sh build` and watch it go
