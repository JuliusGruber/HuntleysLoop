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
├── PROMPT_specs.md            # Spec-writing mode prompt
├── AGENTS.md                  # Operational guide (~60 lines max)
├── IMPLEMENTATION_PLAN.md     # Shared state between iterations (starts empty)
├── specs/                     # Requirements (one file per concern)
│   └── [your-feature].md      # e.g., specs/core-functionality.md
├── src/                       # Application source code (built by Ralph)
│   └── lib/                   # Shared utilities (Ralph's "standard library")
└── .gitignore
```

---

## Files to Create

### 1. `loop.sh` — The Loop

The entire orchestrator. Supports `plan`, `build`, and `specs` modes via argument. Optional max-iterations as second argument. Pushes to remote after each successful iteration.

```bash
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
```

### 2. `PROMPT_specs.md` — Spec-Writing Mode Prompt

Instructs Claude to collaboratively define specs from a JTBD (Job to Be Done). Rules:

- **JTBD → Topics of Concern → Specs pipeline**: Break each job into topics, each describable in one sentence without "and"
- **Specify WHAT (outcomes), not HOW (implementation)** — a different team on a different stack must be able to implement from the spec alone
- **No code blocks** in specs — specs are behavioral, not technical
- **Acceptance criteria are behavioral outcomes** — describe observable results, not implementation steps
- **One spec file per topic of concern** — written to `specs/FILENAME.md`
- Use subagents to load information from URLs into context when researching requirements

### 3. `PROMPT_plan.md` — Planning Mode Prompt

Instructs Claude to:
- **Study** (not "read") `specs/*` to learn requirements using parallel subagents
- **Study** existing `src/` code using parallel subagents
- Do gap analysis (what's built vs. what's specified)
- Output a prioritized TODO list into `IMPLEMENTATION_PLAN.md`
- **Do NOT implement anything** — plan only
- Usually completes in 1-2 iterations

### 4. `PROMPT_build.md` — Building Mode Prompt

#### Phase Structure

Prompts use a phased structure:
- **Phase 0a/0b/0c** — Orient (study specs, study source code, read current plan) using parallel subagents
- **Phases 1-4** — Execute (select task, implement, validate, commit)

#### Main Instructions

Instructs Claude to:
- **Study** `specs/*` and `IMPLEMENTATION_PLAN.md` using parallel subagents
- Pick the most important unfinished task
- Investigate relevant source code before implementing
- Implement it completely, run tests
- Update `IMPLEMENTATION_PLAN.md` (mark done, note discoveries)
- Update `AGENTS.md` with operational learnings (keep it under ~60 lines)
- Create semver git tag (`0.0.x`) for clean builds
- `git commit` and exit

#### Subagent Strategy

Baked into the prompt — the main agent acts as a scheduler:
- Fan out **up to 500 parallel Sonnet subagents** for file reads, searches, and investigation
- **Only 1 subagent for build/tests** — serialized backpressure prevents parallel builds from masking failures
- Use **Opus subagents with "Ultrathink"** for complex reasoning (debugging, architectural decisions)
- Each subagent gets ~156KB of context that gets garbage collected after use

#### Guardrails (Escalating Priority via `999...` Numbering)

Guardrails use escalating `9`, `99`, `999`, ... numbering in the prompt to signal increasing criticality to the model:

1. **"capture the why"** — document reasoning, not just what changed
2. **Single sources of truth** — no migrations/adapters; fix unrelated test failures
3. **Create git tags** for clean builds (semver `0.0.x`)
4. **Add extra logging** if needed for debugging
5. **"keep it up to date"** — `IMPLEMENTATION_PLAN.md` must reflect current state with learnings
6. **Update `AGENTS.md`** with operational learnings — but keep it brief (~60 lines max)
7. **Document bugs** even if unrelated to current work — "resolve them or document them"
8. **"if functionality is missing then it's your job to add it"** — no placeholders or stubs, implement completely
9. **Periodically clean** completed items from `IMPLEMENTATION_PLAN.md`
10. **Fix spec inconsistencies** using Opus subagent with Ultrathink
11. **Status/progress goes in `IMPLEMENTATION_PLAN.md`**, never in `AGENTS.md`

#### Specific Language Patterns

These specific phrasings matter for Claude's behavior:
- **"study"** (not "read" or "look at") — triggers deeper analysis
- **"don't assume not implemented"** — the Achilles' heel guardrail; forces code search before writing
- **"using parallel subagents"** / **"up to N subagents"** — triggers parallel tool use
- **"only 1 subagent for build/tests"** — backpressure control
- **"Ultrathink"** — triggers extended reasoning mode
- **"capture the why"** — prompts documentation of reasoning
- **"keep it up to date"** — prompts plan maintenance
- **"resolve them or document them"** — handles discovered bugs

### 5. `AGENTS.md` — Operational Guide

Loaded every iteration as deterministic context. **Must stay under ~60 lines** — bloat pollutes every future iteration's context window.

Contains:
- **Build & Run** — how to build the project
- **Validation** — test, typecheck, lint commands (the backpressure wiring)
- **Operational Notes** — learnings the agent discovers (self-updating)
- **Codebase Patterns** — conventions to follow

**Anti-pattern**: Do NOT put status updates, progress tracking, or changelogs in `AGENTS.md`. That goes in `IMPLEMENTATION_PLAN.md`. `AGENTS.md` is operational only — "how to build and test", not "what was built".

### 6. `IMPLEMENTATION_PLAN.md` — Shared State

Starts as an empty file. Planning loop populates it. Build loop reads and updates it. This is the only coordination mechanism between loop iterations.

- No pre-specified template — let the LLM manage the format
- Self-correcting: build mode can update priorities and add discovered tasks
- Disposable: regenerate by re-running planning mode when stale/wrong
- Prefer Markdown over JSON for token efficiency

### 7. `specs/` Directory

One spec file per feature/concern. Each file describes ONE topic of concern.

**Spec-Writing Rules:**
- **One-sentence scope test**: if you can't describe the topic in one sentence without "and", split it
- **Specify WHAT, not HOW**: describe desired outcomes and behavioral acceptance criteria, not implementation approach
- **No code blocks**: specs are behavioral, not technical
- **Acceptance criteria are observable outcomes**: "user can see X" not "render X component"
- **Relationships**: 1 JTBD → multiple topics → 1 spec per topic → many tasks per spec

### 8. `.gitignore`

Standard ignores for the project.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Orchestration | Bash `while` loop | No framework needed. The loop IS the agent. |
| State management | `IMPLEMENTATION_PLAN.md` on disk | Survives context resets. Human-readable. |
| Context loading | `cat PROMPT.md \| claude -p` | Deterministic — same files loaded every time. |
| Output format | `--output-format stream-json` | Parseable output for monitoring and debugging. |
| Backpressure | Tests + typecheck + lint in `AGENTS.md` | Rejects bad work automatically. |
| Task granularity | 1 task per iteration | Keeps context usage in the "smart zone" (40-60%). |
| Self-correction | Loop iterations | Wrong? Next iteration reads updated plan and fixes it. |
| Permissions | `--dangerously-skip-permissions` | Required for autonomy — run in a sandbox! |
| Subagent fan-out | Up to 500 Sonnet for reads, 1 for builds | Maximizes throughput while serializing backpressure. |
| Format preference | Markdown over JSON | Better token efficiency for LLM context. |
| Remote sync | `git push` after each iteration | Work isn't only local; survives sandbox loss. |

---

## Critical Principles

1. **You sit OUTSIDE the loop**, not inside it. Your job is tuning guardrails, specs, and `AGENTS.md` — not coding.
2. **Fresh context every iteration** is a feature, not a bug. Prevents context pollution and keeps the agent in the "smart zone."
3. **The plan is disposable.** Wrong plan? Re-run planning mode. Cheap (1-2 iterations).
4. **"Don't assume not implemented"** — the single most important guardrail. Without it, the agent rewrites existing code.
5. **Run in a sandbox.** Docker, Fly Sprites, E2B, Modal, Cloudflare Sandboxes, Daytona — anything isolated. The agent has full permissions. It's not if it gets popped, it's when — control the blast radius.
6. **Specify WHAT, not HOW.** Specs describe outcomes. The agent decides implementation. Prescribing approach wastes context and constrains the agent unnecessarily.
7. **AGENTS.md is operational only.** Keep it under ~60 lines. Status and progress go in `IMPLEMENTATION_PLAN.md`. Bloated `AGENTS.md` pollutes every future iteration.
8. **The main agent is a scheduler.** Expensive work (reads, searches, reasoning) fans out to subagents. Build/test backpressure is serialized to one subagent.

---

## Implementation Order

1. Decide what you want the agent to build (the JTBD / project goal)
2. Break each JTBD into **topics of concern** (one sentence without "and" each)
3. Write spec files in `specs/` — one per topic (or use `PROMPT_specs.md` to generate them)
4. Fill in `AGENTS.md` with build/test/lint commands (~60 lines max)
5. Create `PROMPT_plan.md` and `PROMPT_build.md` with phased structure and escalating guardrails
6. Create `loop.sh`
7. Run `bash loop.sh plan` to generate the implementation plan (1-2 iterations)
8. Review the plan, adjust specs if needed
9. Run `bash loop.sh build` and observe from outside the loop
10. Tune: adjust specs, guardrails, and `AGENTS.md` based on what you observe — then let the loop continue
