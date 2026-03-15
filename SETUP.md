# Ralph Loop Setup

Instructions for setting up the Ralph Loop in a git repository. Create all files inside a `ralphLoop/` folder at the target repo root.

## Prerequisites

- Claude CLI installed and authenticated
- Target directory is a git repository
- Run in a sandbox (Docker, E2B, Modal, Fly Sprites, Daytona, etc.) — the loop has full permissions

## Step 1 — Create directory structure

```
ralphLoop/
├── loop.sh
├── PROMPT_plan.md
├── PROMPT_build.md
├── PROMPT_specs.md
├── AGENTS.md
├── IMPLEMENTATION_PLAN.md    (empty file)
└── specs/                    (empty directory)
```

## Step 2 — Create loop.sh

Copy verbatim:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-build}"          # "plan", "build", or "specs"
MAX_ITERS="${2:-0}"         # 0 = infinite
PROMPT_FILE="$SCRIPT_DIR/PROMPT_${MODE}.md"
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

Make executable: `chmod +x ralphLoop/loop.sh`

## Step 3 — Create PROMPT_plan.md

Copy verbatim:

```markdown
# Planning Mode

You are an autonomous planning agent. Your job is to study specs and source code, perform gap analysis, and produce a prioritized implementation plan. You do NOT implement anything.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `specs/` to understand the full scope of requirements. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Using parallel subagents, study the existing `src/` directory and any other source files to understand what is already built. Don't assume anything is missing — search first.

## Phase 0c — Read Current Plan

Read `IMPLEMENTATION_PLAN.md` if it exists. Understand what has already been planned or completed.

## Phase 1 — Gap Analysis

Compare specs against existing source code:
- What is fully implemented and passing tests?
- What is partially implemented?
- What is completely missing?
- What is implemented but inconsistent with specs?

## Phase 2 — Prioritize

Order tasks by:
1. Dependencies (what must exist before other things can be built)
2. Foundational infrastructure (build system, test harness, core types)
3. Core functionality (the primary JTBD)
4. Edge cases and error handling
5. Polish and refinement

## Phase 3 — Write Plan

Write the prioritized task list to `IMPLEMENTATION_PLAN.md`. Each task should:
- Be completable in a single agent iteration
- Have a clear definition of done
- Note any dependencies on other tasks

## Rules

9. Capture the **why** — document reasoning behind prioritization decisions.
99. Don't assume functionality is missing. Study the source code thoroughly before listing a task.
999. Tasks must be scoped small enough for one iteration — if a task feels large, split it.
9999. Do NOT implement anything. Planning only.
99999. Prefer Markdown format. No JSON.
```

## Step 4 — Create PROMPT_build.md

Copy verbatim:

```markdown
# Building Mode

You are an autonomous building agent. Each iteration you pick one task, implement it completely, validate it, and commit. Then you exit so the next iteration starts with a fresh context.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `specs/` to understand requirements for the current work. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Using parallel subagents, study the existing `src/` directory to understand what is already built. Don't assume not implemented — search the codebase first.

## Phase 0c — Read Plan

Read `IMPLEMENTATION_PLAN.md` to understand the current prioritized task list, what's done, and what's next.

## Phase 1 — Select Task

Pick the **most important unfinished task** from `IMPLEMENTATION_PLAN.md`. Consider dependencies — don't pick a task whose prerequisites aren't done.

## Phase 2 — Implement

1. Investigate the relevant source code using parallel subagents before writing anything
2. Implement the task completely — no placeholders, no stubs, no TODOs
3. If functionality is missing then it's your job to add it
4. Follow patterns established in `src/lib/` and documented in `AGENTS.md`

## Phase 3 — Validate

Run the validation commands from `AGENTS.md` using only 1 subagent for build/tests (serialized backpressure):
- Build must pass
- Tests must pass
- Type checking must pass
- Linting must pass

If validation fails, fix the issue and re-validate. Do not commit broken code.

## Phase 4 — Commit and Update

1. Update `IMPLEMENTATION_PLAN.md` — mark the task as done, note any discoveries or new tasks
2. Update `AGENTS.md` with operational learnings if you discovered something useful (keep it under ~60 lines total)
3. Create a git commit with a descriptive message that captures the **why**
4. Create a semver git tag (`0.0.x`) if the build is clean
5. Exit cleanly so the loop can restart with a fresh context

## Guardrails

9. Capture the **why** in commit messages and plan updates — document reasoning, not just what changed.

99. Single sources of truth — no migrations, no adapters, no compatibility shims. Fix unrelated test failures you encounter.

999. Create git tags for clean builds using semver `0.0.x` format.

9999. Add extra logging if needed for debugging. Remove it when the issue is resolved.

99999. Keep `IMPLEMENTATION_PLAN.md` up to date with learnings, discovered tasks, and current state.

999999. Update `AGENTS.md` with operational learnings — but keep it brief. ~60 lines max. Status and progress go in `IMPLEMENTATION_PLAN.md`, never in `AGENTS.md`.

9999999. Resolve bugs or document them — even if unrelated to your current task. If you find a bug, either fix it or add it to `IMPLEMENTATION_PLAN.md`.

99999999. If functionality is missing then it's your job to add it. No placeholders, no stubs, no "TODO: implement later". Implement completely or don't touch it.

999999999. Periodically clean completed items from `IMPLEMENTATION_PLAN.md` to keep it focused.

9999999999. If you find spec inconsistencies, resolve them using an Opus subagent with Ultrathink. Document the resolution.

99999999999. Status and progress tracking goes in `IMPLEMENTATION_PLAN.md`, never in `AGENTS.md`. Keep `AGENTS.md` operational only.

## Subagent Strategy

- Use the main context as a **scheduler** — don't do expensive work in main context
- Fan out **parallel subagents** for file reads, searches, and investigation — one per file, up to ~10 concurrent (Pro subscription rate limits apply)
- For trivially small directories (< 5 files), skip subagents and read directly
- Use **only 1 subagent for build/tests** — serialized backpressure prevents parallel builds from masking failures
- Use **Opus subagents with Ultrathink** sparingly for complex reasoning, debugging, and architectural decisions
```

## Step 5 — Create PROMPT_specs.md

Copy verbatim:

```markdown
# Spec-Writing Mode

You are writing specification files for an autonomous coding agent. Your job is to turn a Job to Be Done (JTBD) into clear, behavioral specs that any team could implement on any stack.

## Phase 0 — Orient

Study the existing `specs/` directory using parallel subagents to understand what specs already exist. Study `AGENTS.md` for project context.

## Phase 1 — Break Down the JTBD

1. Identify the Job to Be Done from the user's request or from project context
2. Break the JTBD into **topics of concern**
3. Apply the **one-sentence scope test**: if you can't describe a topic in one sentence without "and", split it further
4. Each topic becomes one spec file

## Phase 2 — Write Specs

For each topic of concern, create a spec file at `specs/TOPIC_NAME.md`.

Each spec must contain:
- **Summary** — one sentence describing the topic
- **Context** — why this matters, who benefits
- **Acceptance Criteria** — observable behavioral outcomes (what a user or system can see/do)
- **Edge Cases** — boundary conditions and error scenarios
- **Out of Scope** — what this spec intentionally does NOT cover

## Rules

9. Specify **WHAT** (outcomes), never **HOW** (implementation). A different team on a different stack must be able to implement from the spec alone.
99. **No code blocks** in specs. Specs are behavioral, not technical.
999. Acceptance criteria must be **observable outcomes**: "user can see X", "system responds with Y" — not "render component Z" or "call function W".
9999. One spec file per topic of concern. Never combine multiple topics.
99999. Use subagents to load information from URLs when researching requirements.
999999. Do NOT implement anything. Write specs only.
```

## Step 6 — Create AGENTS.md

<!-- CUSTOMIZE: this is the only file that must be adapted to the target project -->

Create `ralphLoop/AGENTS.md` and fill in the project's actual build, test, typecheck, and lint commands. Must stay under ~60 lines. This is the backpressure mechanism — without real commands, the loop cannot validate its work.

Template (adapt the `CUSTOMIZE` sections to the target project):

    # AGENTS.md — Operational Guide

    ## Build & Run

    <!-- CUSTOMIZE: replace with your project's build and run commands -->
    ```bash
    # Build
    # <your build command>

    # Run
    # <your run command>
    ```

    ## Validation

    <!-- CUSTOMIZE: replace with your project's test, typecheck, and lint commands -->
    <!-- These commands are your backpressure — they reject bad work -->
    ```bash
    # Tests
    # <your test command>

    # Type checking
    # <your typecheck command>

    # Linting
    # <your lint command>
    ```

    ## Operational Notes

    <!-- Agent-discovered learnings go here. Keep this section brief. -->

    ## Codebase Patterns

    <!-- CUSTOMIZE: replace with your project's conventions -->
    - One concern per file
    - Shared utilities go in `src/lib/`

## Step 7 — Create empty IMPLEMENTATION_PLAN.md

Create an empty file at `ralphLoop/IMPLEMENTATION_PLAN.md`. The planning loop will populate it.

## Step 8 — Post-scaffold

After creating all files:

1. **Customize AGENTS.md** — detect the project's build system and fill in the actual build/test/lint commands. Look for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, etc.
2. **Ask the user** for their Job to Be Done (JTBD) — what should the loop build?
3. **Run planning mode** first: `bash ralphLoop/loop.sh plan 2`
4. Review the generated `IMPLEMENTATION_PLAN.md`, then run build mode: `bash ralphLoop/loop.sh build`
