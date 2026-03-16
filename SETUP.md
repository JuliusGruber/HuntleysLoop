# Ralph Loop Setup — Skill Instructions

You are an autonomous agent scaffolding the Ralph Loop into a target project. Execute each step below in order. Where you see `<!-- CUSTOMIZE -->` markers, adapt the content to the target project using information gathered in Step 0. Do NOT leave placeholder commands — detect and fill in real values.

## Step 0 — Analyze the target project

Before creating any files, study the target project to gather information you will need for customization:

1. **Detect language and framework** — look for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, `build.gradle`, `pom.xml`, `CMakeLists.txt`, `.csproj`, etc.
2. **Map source directories** — identify where application source code lives (e.g., `src/`, `app/`, `lib/`, `packages/`, or root-level). Note the main source directory and any shared utilities directory.
3. **Find build commands** — extract build, run, test, typecheck, and lint commands from the project's config files, scripts, or CI configuration.
4. **Note conventions** — observe naming patterns, file organization, and coding conventions already in use.

Keep this information ready — you will use it to customize `AGENTS.md` in Step 6.

## Step 1 — Create directory structure

```
ralphLoop/
├── loop.sh
├── PROMPT_plan.md
├── PROMPT_build.md
├── PROMPT_specs.md
├── AGENTS.md
├── JTBD.md                   (Job to Be Done — user fills this in)
├── IMPLEMENTATION_PLAN.md    (empty file — planning loop populates it)
├── specs/                    (empty directory — specs loop populates it)
└── documentation/
    ├── running-the-ralph-loop.md
    └── ralph-loop-design.md
```

## Step 2 — Create loop.sh

Copy verbatim. Make executable with `chmod +x ralphLoop/loop.sh`.

```bash
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
```

## Step 3 — Create PROMPT_plan.md

Copy verbatim:

```markdown
# Planning Mode

You are an autonomous planning agent. Your job is to study specs and source code, perform gap analysis, and produce a prioritized implementation plan. You do NOT implement anything.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `ralphLoop/specs/` to understand the full scope of requirements. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Read `ralphLoop/AGENTS.md` for the project's source directory paths and conventions. Then, using parallel subagents, study the existing source directories to understand what is already built. Don't assume anything is missing — search first.

## Phase 0c — Read Current Plan

Read `ralphLoop/IMPLEMENTATION_PLAN.md` if it exists. Understand what has already been planned or completed.

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

Write the prioritized task list to `ralphLoop/IMPLEMENTATION_PLAN.md`. Each task should:
- Be completable in a single agent iteration
- Have a clear definition of done
- Note any dependencies on other tasks

## Phase 4 — Commit

1. Stage all new and modified plan files
2. Create a git commit with a descriptive message summarizing the planning work done
3. Exit cleanly so the loop can restart with a fresh context

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

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `ralphLoop/specs/` to understand requirements for the current work. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Read `ralphLoop/AGENTS.md` for the project's source directory paths, build commands, and conventions. Then, using parallel subagents, study the existing source directories to understand what is already built. Don't assume not implemented — search the codebase first.

## Phase 0c — Read Plan

Read `ralphLoop/IMPLEMENTATION_PLAN.md` to understand the current prioritized task list, what's done, and what's next.

## Phase 1 — Select Task

Pick the **most important unfinished task** from `ralphLoop/IMPLEMENTATION_PLAN.md`. Consider dependencies — don't pick a task whose prerequisites aren't done.

## Phase 2 — Implement

1. Investigate the relevant source code using parallel subagents before writing anything
2. Implement the task completely — no placeholders, no stubs, no TODOs
3. If functionality is missing then it's your job to add it
4. Follow patterns documented in `ralphLoop/AGENTS.md`

## Phase 3 — Validate

Run the validation commands from `ralphLoop/AGENTS.md` using only 1 subagent for build/tests (serialized backpressure):
- Build must pass
- Tests must pass
- Type checking must pass
- Linting must pass

If validation fails, fix the issue and re-validate. Do not commit broken code.

## Phase 4 — Commit and Update

1. Update `ralphLoop/IMPLEMENTATION_PLAN.md` — mark the task as done, note any discoveries or new tasks
2. Update `ralphLoop/AGENTS.md` with operational learnings if you discovered something useful (keep it under ~60 lines total)
3. Create a git commit with a descriptive message that captures the **why**
4. Create a semver git tag (`0.0.x`) if the build is clean
5. Exit cleanly so the loop can restart with a fresh context

## Guardrails

9. Capture the **why** in commit messages and plan updates — document reasoning, not just what changed.

99. Single sources of truth — no migrations, no adapters, no compatibility shims. Fix unrelated test failures you encounter.

999. Create git tags for clean builds using semver `0.0.x` format.

9999. Add extra logging if needed for debugging. Remove it when the issue is resolved.

99999. Keep `ralphLoop/IMPLEMENTATION_PLAN.md` up to date with learnings, discovered tasks, and current state.

999999. Update `ralphLoop/AGENTS.md` with operational learnings — but keep it brief. ~60 lines max. Status and progress go in `ralphLoop/IMPLEMENTATION_PLAN.md`, never in `ralphLoop/AGENTS.md`.

9999999. Resolve bugs or document them — even if unrelated to your current task. If you find a bug, either fix it or add it to `ralphLoop/IMPLEMENTATION_PLAN.md`.

99999999. If functionality is missing then it's your job to add it. No placeholders, no stubs, no "TODO: implement later". Implement completely or don't touch it.

999999999. Periodically clean completed items from `ralphLoop/IMPLEMENTATION_PLAN.md` to keep it focused.

9999999999. If you find spec inconsistencies, resolve them using an Opus subagent with Ultrathink. Document the resolution.

99999999999. Status and progress tracking goes in `ralphLoop/IMPLEMENTATION_PLAN.md`, never in `ralphLoop/AGENTS.md`. Keep `ralphLoop/AGENTS.md` operational only.

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

1. Read `ralphLoop/JTBD.md` to understand what the user wants built
2. Study the existing `ralphLoop/specs/` directory using parallel subagents to understand what specs already exist
3. Study `ralphLoop/AGENTS.md` for project context and conventions

## Phase 1 — Break Down the JTBD

1. Identify the Job to Be Done from `ralphLoop/JTBD.md`
2. Break the JTBD into **topics of concern**
3. Apply the **one-sentence scope test**: if you can't describe a topic in one sentence without "and", split it further
4. Each topic becomes one spec file

## Phase 2 — Write Specs

For each topic of concern, create a spec file at `ralphLoop/specs/TOPIC_NAME.md`.

Each spec must contain:
- **Summary** — one sentence describing the topic
- **Context** — why this matters, who benefits
- **Acceptance Criteria** — observable behavioral outcomes (what a user or system can see/do)
- **Edge Cases** — boundary conditions and error scenarios
- **Out of Scope** — what this spec intentionally does NOT cover

## Phase 3 — Commit

1. Stage all new and modified spec files
2. Create a git commit with a descriptive message summarizing what specs were written or updated
3. Exit cleanly so the loop can restart with a fresh context

## Rules

9. Specify **WHAT** (outcomes), never **HOW** (implementation). A different team on a different stack must be able to implement from the spec alone.
99. **No code blocks** in specs. Specs are behavioral, not technical.
999. Acceptance criteria must be **observable outcomes**: "user can see X", "system responds with Y" — not "render component Z" or "call function W".
9999. One spec file per topic of concern. Never combine multiple topics.
99999. Use subagents to load information from URLs when researching requirements.
999999. Do NOT implement anything. Write specs only.
```

## Step 6 — Create AGENTS.md

This is the **only file that must be fully adapted** to the target project. Use the information gathered in Step 0 to fill in every section with real commands and paths. Do NOT leave placeholder comments or `<!-- CUSTOMIZE -->` markers in the final file. If the project has no command for a category (e.g., no type checker), omit that line entirely. Must stay under ~60 lines total.

Template structure (fill in all sections using Step 0 findings):

    # AGENTS.md — Operational Guide

    ## Source Directories

    <!-- CUSTOMIZE: list the project's actual source directories from Step 0 -->
    - Main source: `src/`
    - Shared utilities: `src/lib/`

    ## Build & Run

    <!-- CUSTOMIZE: fill with actual build and run commands from Step 0 -->
    ```bash
    # Build
    npm run build

    # Run
    npm run dev
    ```

    ## Validation

    <!-- CUSTOMIZE: fill with actual test, typecheck, and lint commands from Step 0 -->
    <!-- These commands are your backpressure — they reject bad work -->
    ```bash
    # Tests
    npm test

    # Type checking
    npx tsc --noEmit

    # Linting
    npm run lint
    ```

    ## Operational Notes

    <!-- Start empty. Agent-discovered learnings go here during loop execution. -->

    ## Codebase Patterns

    <!-- CUSTOMIZE: fill with actual conventions observed in Step 0 -->
    - One concern per file

## Step 7 — Create JTBD.md

Create `ralphLoop/JTBD.md` with placeholder content for the user to fill in before running specs mode:

```markdown
# Job to Be Done

<!-- Describe WHAT you want built here. Focus on outcomes, not implementation. -->
<!-- Example: "Users can sign up, log in, and manage their profile." -->
<!-- The specs loop will break this into detailed behavioral specs. -->
```

## Step 8 — Create empty IMPLEMENTATION_PLAN.md

Create an empty file at `ralphLoop/IMPLEMENTATION_PLAN.md`. The planning loop will populate it.

## Step 9 — Create ralphLoop/documentation/running-the-ralph-loop.md

Copy verbatim:

```markdown
# Running the Ralph Loop

After scaffolding the `ralphLoop/` directory (via the setup skill or by pasting the SETUP.md prompt), follow this guide to start and operate the loop.

---

## Prerequisites

- **Claude CLI** installed and authenticated (`claude --version` to verify)
- **Git repository** initialized with at least one commit
- **Sandbox environment** (Docker, E2B, Modal, Daytona, etc.) — the loop runs with `--dangerously-skip-permissions`, so never run it on an uncontained machine

## Quick Start

\`\`\`bash
# 1. Describe what you want built
#    Open ralphLoop/JTBD.md and replace the placeholder with your Job to Be Done.

# 2. Generate specs from the JTBD
bash ralphLoop/loop.sh specs 2

# 3. Review the generated specs in ralphLoop/specs/ — edit as needed

# 4. Generate an implementation plan
bash ralphLoop/loop.sh plan 2

# 5. Review ralphLoop/IMPLEMENTATION_PLAN.md — edit as needed

# 6. Build autonomously
bash ralphLoop/loop.sh build
\`\`\`

## Loop Modes

The loop script (`ralphLoop/loop.sh`) accepts two arguments:

\`\`\`
bash ralphLoop/loop.sh <mode> [max_iterations]
\`\`\`

| Mode | What it does | Typical iterations |
|---|---|---|
| `specs` | Reads `JTBD.md` and produces behavioral spec files in `ralphLoop/specs/` | 1-2 |
| `plan` | Reads specs and source code, writes a prioritized task list to `IMPLEMENTATION_PLAN.md` | 1-2 |
| `build` | Picks the next task from the plan, implements it, validates, commits, and exits so the next iteration starts fresh | Until all tasks are done |

If `max_iterations` is omitted or `0`, the loop runs indefinitely (useful for `build` mode).

## Choosing a Model

The loop defaults to Opus. Override with the `RALPH_MODEL` environment variable:

\`\`\`bash
# Use Sonnet for faster, cheaper iterations
RALPH_MODEL=sonnet bash ralphLoop/loop.sh build

# Use Opus (default) for maximum capability
RALPH_MODEL=opus bash ralphLoop/loop.sh build
\`\`\`

## The Workflow in Detail

### 1. Write Your JTBD

Edit `ralphLoop/JTBD.md` to describe **what** you want built. Focus on outcomes, not implementation details.

Good: "Users can sign up with email, log in, reset their password, and view their profile."
Bad: "Create a React component using NextAuth with Prisma adapter..."

### 2. Run Specs Mode

\`\`\`bash
bash ralphLoop/loop.sh specs 2
\`\`\`

The agent reads your JTBD and breaks it into one spec file per topic of concern in `ralphLoop/specs/`. Each spec contains a summary, context, acceptance criteria, edge cases, and out-of-scope notes.

Review the generated specs. This is your best leverage point — fixing a spec now is much cheaper than fixing code later.

### 3. Run Planning Mode

\`\`\`bash
bash ralphLoop/loop.sh plan 2
\`\`\`

The agent studies the specs and your existing source code, performs gap analysis, and writes a prioritized task list to `ralphLoop/IMPLEMENTATION_PLAN.md`. Tasks are ordered by dependencies, then foundational work, then core functionality.

Review the plan. Reorder or remove tasks if needed — the build loop trusts this file.

### 4. Run Build Mode

\`\`\`bash
bash ralphLoop/loop.sh build
\`\`\`

Each iteration:

1. Reads specs, source code, and the current plan
2. Picks the most important unfinished task
3. Implements it completely (no stubs or TODOs)
4. Validates — build, tests, typecheck, lint must all pass
5. Commits, tags the clean build, and pushes
6. Updates the plan, then exits for a fresh context

The loop continues until all tasks are done or you stop it with `Ctrl+C`.

### 5. Monitor Progress

Watch the terminal output, or check progress between iterations:

\`\`\`bash
# See what's been done and what's next
cat ralphLoop/IMPLEMENTATION_PLAN.md

# See commit history
git log --oneline

# See tagged builds
git tag
\`\`\`

## Restarting and Recovering

| Situation | What to do |
|---|---|
| Plan is wrong or stale | Re-run `bash ralphLoop/loop.sh plan 2` — it regenerates from specs |
| Agent went off track | Edit `IMPLEMENTATION_PLAN.md` to correct priorities, then resume `build` |
| Want to change scope | Edit `JTBD.md`, re-run `specs`, then `plan`, then `build` |
| Loop stopped mid-iteration | Just restart `bash ralphLoop/loop.sh build` — it reads the plan and picks up where it left off |
| Build keeps failing | Check `ralphLoop/AGENTS.md` — the validation commands must match your project |

## Tips

- **You sit outside the loop.** Your job is tuning specs, the plan, and `AGENTS.md` — not writing code.
- **Fresh context every iteration is a feature.** The agent reads the plan from disk each time, so it never accumulates stale assumptions.
- **The plan is disposable.** Wrong plan? Re-run planning mode. It's cheap (1-2 iterations).
- **Keep `AGENTS.md` under ~60 lines.** It's loaded every iteration — bloat wastes context.
- **Review specs carefully.** Spec quality is the highest-leverage input to the entire loop.
```

## Step 10 — Create ralphLoop/documentation/ralph-loop-design.md

Copy verbatim:

```markdown
# Ralph Loop — Design Reference

Design rationale, principles, and prompt engineering patterns behind the Ralph Loop. For setup instructions, see `SETUP.md` at the repo root.

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
| Subagent fan-out | Up to ~10 concurrent for reads, 1 for builds | Maximizes throughput within Pro-tier rate limits while serializing backpressure. |
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

## Prompt Engineering Patterns

### Specific Language Patterns

These phrasings matter for Claude's behavior:

- **"study"** (not "read" or "look at") — triggers deeper analysis
- **"don't assume not implemented"** — the Achilles' heel guardrail; forces code search before writing
- **"using parallel subagents"** / **"up to ~10 concurrent"** — triggers parallel tool use within Pro-tier limits
- **"only 1 subagent for build/tests"** — backpressure control
- **"Ultrathink"** — triggers extended reasoning mode
- **"capture the why"** — prompts documentation of reasoning
- **"keep it up to date"** — prompts plan maintenance
- **"resolve them or document them"** — handles discovered bugs

### Guardrails (Escalating Priority via `999...` Numbering)

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

### Subagent Strategy

The main agent acts as a scheduler:

- Fan out **parallel subagents** for file reads, searches, and investigation — one per file, up to ~10 concurrent (Pro subscription rate limits apply)
- For trivially small directories (< 5 files), skip subagents and read directly
- **Only 1 subagent for build/tests** — serialized backpressure prevents parallel builds from masking failures
- Use **Opus subagents with "Ultrathink" sparingly** for complex reasoning (debugging, architectural decisions)

### Phase Structure (Build Mode)

Prompts use a phased structure:
- **Phase 0a/0b/0c** — Orient (study specs, study source code, read current plan) using parallel subagents
- **Phases 1-4** — Execute (select task, implement, validate, commit)

---

## File Roles

### AGENTS.md

Loaded every iteration as deterministic context. **Must stay under ~60 lines** — bloat pollutes every future iteration's context window.

Contains: Build & Run, Validation, Operational Notes, Codebase Patterns.

**Anti-pattern**: Do NOT put status updates, progress tracking, or changelogs in `AGENTS.md`. That goes in `IMPLEMENTATION_PLAN.md`. `AGENTS.md` is operational only — "how to build and test", not "what was built".

### IMPLEMENTATION_PLAN.md

Starts as an empty file. Planning loop populates it. Build loop reads and updates it. This is the only coordination mechanism between loop iterations.

- No pre-specified template — let the LLM manage the format
- Self-correcting: build mode can update priorities and add discovered tasks
- Disposable: regenerate by re-running planning mode when stale/wrong
- Prefer Markdown over JSON for token efficiency

### specs/

One spec file per feature/concern. Each file describes ONE topic of concern.

- **One-sentence scope test**: if you can't describe the topic in one sentence without "and", split it
- **Specify WHAT, not HOW**: describe desired outcomes and behavioral acceptance criteria, not implementation approach
- **No code blocks**: specs are behavioral, not technical
- **Acceptance criteria are observable outcomes**: "user can see X" not "render X component"
- **Relationships**: 1 JTBD → multiple topics → 1 spec per topic → many tasks per spec
```

## Step 11 — Verify setup

Confirm the scaffolding is correct:

1. All files from Step 1 exist in `ralphLoop/`
2. `ralphLoop/loop.sh` is executable (`chmod +x`)
3. `ralphLoop/AGENTS.md` contains **real commands** — not placeholder comments. If any section still has `<!-- CUSTOMIZE -->` or `# <your ... command>`, go back and fill it in using Step 0 findings
4. All `ralphLoop/PROMPT_*.md` files exist and reference `ralphLoop/` paths
5. `ralphLoop/specs/` directory exists
6. `ralphLoop/documentation/running-the-ralph-loop.md` exists
7. `ralphLoop/documentation/ralph-loop-design.md` exists

## Step 12 — Tell the user what to do next

After scaffolding is complete, tell the user:

1. **Edit `ralphLoop/JTBD.md`** — describe what you want the loop to build
2. **Run specs mode**: `bash ralphLoop/loop.sh specs 2` — generates behavioral specs from the JTBD
3. **Review specs** in `ralphLoop/specs/` — adjust if needed
4. **Run planning mode**: `bash ralphLoop/loop.sh plan 2` — generates implementation plan
5. **Review plan** in `ralphLoop/IMPLEMENTATION_PLAN.md` — adjust if needed
6. **Run build mode**: `bash ralphLoop/loop.sh build` — autonomously implements until done
7. **Override model** if needed: `RALPH_MODEL=sonnet bash ralphLoop/loop.sh build`

**Important**: Run the loop in a sandbox environment (Docker, E2B, Modal, Daytona, etc.) — it has full permissions via `--dangerously-skip-permissions`.
