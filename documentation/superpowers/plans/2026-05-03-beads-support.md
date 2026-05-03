# Beads Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a parallel beads-driven Ralph Loop track to HuntleysLoop without modifying the existing markdown track. Users paste a single one-liner into Claude Code and get a fully scaffolded `ralphLoopBeads/` directory whose coordination state is the `bd` issue graph rather than `IMPLEMENTATION_PLAN.md`.

**Architecture:** Mirror the existing markdown track end-to-end: a self-contained `SETUP_BEADS.md` scaffold doc, two skill files (portable + this-repo), a `ralphLoopBeads/` reference example, and a design rationale doc. The new track diverges only where beads replaces `IMPLEMENTATION_PLAN.md` (Step 0 pre-flight, Step 1 directory layout, plan/build prompts, Step 8 `bd init`). Everything else is copied verbatim. Plan mode is strictly append-only; build mode resumes its own in-progress claims before querying ready work; `loop.sh` adds one `git pull --rebase` line and never calls `bd` itself.

**Tech Stack:** Bash, Markdown, Claude Code skill format (`---` frontmatter), `bd` CLI (beads). No application source code, no test framework — this is a documentation/scaffold-template change.

**Authoritative source:** `documentation/superpowers/specs/2026-05-03-beads-support-design.md`. Where this plan and the spec disagree, the spec wins; flag the discrepancy.

**Hard constraint:** The existing markdown track must be byte-identical after these tasks. The list of files that MUST NOT be touched: `SETUP.md`, all of `ralphLoop/`, `skills/setup-ralph-loop.md`, `.claude/skills/setup-ralph-loop/SKILL.md`, `documentation/ralph-loop-design.md`, `CLAUDE.md`. The verification task at the end enforces this.

**Reference example caveat (Section 9 of spec):** `loop.sh` never calls `bd`. The agent (Claude) issues every `bd` command via the prompts. Do not add `bd` calls to `loop.sh` — not even for the reference example.

**`.beads/` in the repo's reference example:** The reference `ralphLoopBeads/` in this repo intentionally does NOT contain a real `.beads/` directory. The reference shows the directory layout the user will see post-scaffold; `.beads/` is created at scaffold time (Step 8 of `SETUP_BEADS.md`) in the user's project. Shipping a real `.beads/` here would bloat the repo with synthetic test issues and require `bd` to be installed on every contributor's machine. Document this choice in the design doc (Task 11).

---

## File Inventory

**New files (create):**
- `ralphLoopBeads/loop.sh`
- `ralphLoopBeads/PROMPT_specs.md`
- `ralphLoopBeads/PROMPT_plan.md`
- `ralphLoopBeads/PROMPT_build.md`
- `ralphLoopBeads/AGENTS.md`
- `ralphLoopBeads/JTBD.md`
- `ralphLoopBeads/specs/.gitkeep`
- `skills/setup-ralph-loop-beads.md`
- `.claude/skills/setup-ralph-loop-beads/SKILL.md`
- `SETUP_BEADS.md`
- `documentation/ralph-loop-beads-design.md`

**Modified files (edit):**
- `README.md` (add beads one-liner block, four file-table rows, intro sentence)

**Files that MUST NOT change:**
- `SETUP.md`
- `ralphLoop/` (all files)
- `skills/setup-ralph-loop.md`
- `.claude/skills/setup-ralph-loop/SKILL.md`
- `documentation/ralph-loop-design.md`
- `CLAUDE.md`

---

## Task 1: Reference example — placeholder files (`JTBD.md`, `specs/.gitkeep`)

**Files:**
- Create: `ralphLoopBeads/JTBD.md`
- Create: `ralphLoopBeads/specs/.gitkeep`

These mirror `ralphLoop/JTBD.md` and `ralphLoop/specs/.gitkeep` exactly. Starting with the smallest files lets the rest of the reference example accumulate against a tracked directory.

- [ ] **Step 1: Create `ralphLoopBeads/JTBD.md` with the placeholder content**

Content (identical to `ralphLoop/JTBD.md`):

````markdown
# Job to Be Done

<!-- Describe WHAT you want built here. Focus on outcomes, not implementation. -->
<!-- Example: "Users can sign up, log in, and manage their profile." -->
<!-- The specs loop will break this into detailed behavioral specs. -->
````

- [ ] **Step 2: Create `ralphLoopBeads/specs/.gitkeep` (empty file)**

The file exists solely to make git track the otherwise-empty directory. Same as `ralphLoop/specs/.gitkeep`.

- [ ] **Step 3: Verify the reference `JTBD.md` is byte-identical to the markdown track's**

Run:

```bash
diff ralphLoop/JTBD.md ralphLoopBeads/JTBD.md
```

Expected: no output (files identical).

- [ ] **Step 4: Verify the `.gitkeep` exists**

Run:

```bash
test -f ralphLoopBeads/specs/.gitkeep && echo OK
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add ralphLoopBeads/JTBD.md ralphLoopBeads/specs/.gitkeep
git commit -m "feat(beads): add ralphLoopBeads JTBD and specs placeholders"
```

---

## Task 2: Reference example — `ralphLoopBeads/loop.sh`

**Files:**
- Create: `ralphLoopBeads/loop.sh`

Mirrors `ralphLoop/loop.sh` exactly except it adds a single `git pull --rebase 2>/dev/null || true` line inside the `while` body, **before** the `cat | claude -p` invocation. The reason (per spec Section 5 / edge case 3): `.beads/` is genuinely shared state — it lives in git, so a divergent clone elsewhere can introduce conflicts that are easier to resolve eagerly than reactively. Per Section 9 of the spec: `loop.sh` never calls `bd`. Do not add any `bd` invocation to this script.

- [ ] **Step 1: Create `ralphLoopBeads/loop.sh` with this exact content**

````bash
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

  # Pull rebased so .beads/ stays in sync if another clone is also pushing
  git pull --rebase 2>/dev/null || true

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
````

- [ ] **Step 2: Make it executable**

```bash
chmod +x ralphLoopBeads/loop.sh
```

- [ ] **Step 3: Confirm the `git pull --rebase` line is present and `bd` is NOT referenced**

```bash
grep -n 'git pull --rebase 2>/dev/null || true' ralphLoopBeads/loop.sh
grep -nc '\bbd\b' ralphLoopBeads/loop.sh || echo "0 (correct: loop.sh must not call bd)"
```

Expected: the `git pull --rebase` line is present, and the `bd` grep prints `0` (or "no matches"). If `bd` appears anywhere, remove it — Section 9 of the spec is explicit: only the agent (via prompts) calls `bd`.

- [ ] **Step 4: Sanity-check shell syntax**

```bash
bash -n ralphLoopBeads/loop.sh && echo "syntax OK"
```

Expected: `syntax OK` (no parse errors).

- [ ] **Step 5: Confirm executable bit on Unix; on Windows, rely on `.gitattributes`**

```bash
ls -l ralphLoopBeads/loop.sh
```

Expected: mode shows `x` (e.g. `-rwxr-xr-x`) on Unix. On Windows the existing `.gitattributes` (`* text=auto eol=lf` plus the `*.sh` rules already in this repo) handles line endings; the executable bit is set via `git update-index --chmod=+x` if `chmod` is unavailable.

- [ ] **Step 6: Diff against the markdown track to confirm only the `git pull --rebase` line differs**

```bash
diff ralphLoop/loop.sh ralphLoopBeads/loop.sh
```

Expected diff: ONE inserted block — the comment line (`# Pull rebased so .beads/ stays in sync ...`), the `git pull --rebase 2>/dev/null || true` line, and a blank line, inserted between the iteration banner echo and the `cat "$PROMPT_FILE" | claude -p` call. Nothing else should differ.

- [ ] **Step 7: Commit**

```bash
git add ralphLoopBeads/loop.sh
git update-index --chmod=+x ralphLoopBeads/loop.sh
git commit -m "feat(beads): add ralphLoopBeads loop.sh with git pull --rebase"
```

---

## Task 3: Reference example — `ralphLoopBeads/PROMPT_specs.md`

**Files:**
- Create: `ralphLoopBeads/PROMPT_specs.md`

Per spec Section 4 Step 5: "Identical to current `SETUP.md`. Specs stay markdown." That means structurally identical to `ralphLoop/PROMPT_specs.md`, but the embedded `ralphLoop/` paths must be rewritten to `ralphLoopBeads/`. Otherwise the specs prompt would write into the wrong directory.

- [ ] **Step 1: Create `ralphLoopBeads/PROMPT_specs.md` with this exact content**

````markdown
# Spec-Writing Mode

You are writing specification files for an autonomous coding agent. Your job is to turn a Job to Be Done (JTBD) into clear, behavioral specs that any team could implement on any stack.

## Phase 0 — Orient

1. Read `ralphLoopBeads/JTBD.md` to understand what the user wants built
2. Study the existing `ralphLoopBeads/specs/` directory using parallel subagents to understand what specs already exist
3. Study `ralphLoopBeads/AGENTS.md` for project context and conventions

## Phase 1 — Break Down the JTBD

1. Identify the Job to Be Done from `ralphLoopBeads/JTBD.md`
2. Break the JTBD into **topics of concern**
3. Apply the **one-sentence scope test**: if you can't describe a topic in one sentence without "and", split it further
4. Each topic becomes one spec file

## Phase 2 — Write Specs

For each topic of concern, create a spec file at `ralphLoopBeads/specs/TOPIC_NAME.md`.

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
````

- [ ] **Step 2: Confirm path rewrite is total**

```bash
grep -n 'ralphLoop/' ralphLoopBeads/PROMPT_specs.md && echo "BAD: stray ralphLoop/ path" || echo "OK: all paths use ralphLoopBeads/"
grep -c 'ralphLoopBeads/' ralphLoopBeads/PROMPT_specs.md
```

Expected: the first grep prints "OK"; the second prints a count > 0 (every original `ralphLoop/` reference was rewritten). The file must contain zero literal `ralphLoop/` substrings — only `ralphLoopBeads/`.

- [ ] **Step 3: Confirm structural parity with the markdown-track prompt**

```bash
diff <(sed 's|ralphLoopBeads/|ralphLoop/|g' ralphLoopBeads/PROMPT_specs.md) ralphLoop/PROMPT_specs.md
```

Expected: no output. After substituting the directory name back, the file is byte-identical to `ralphLoop/PROMPT_specs.md`. If anything else differs, fix it before committing.

- [ ] **Step 4: Commit**

```bash
git add ralphLoopBeads/PROMPT_specs.md
git commit -m "feat(beads): add ralphLoopBeads PROMPT_specs.md (paths rewritten)"
```

---

## Task 4: Reference example — `ralphLoopBeads/AGENTS.md`

**Files:**
- Create: `ralphLoopBeads/AGENTS.md`

Per spec Section 4 Step 6: same template as `ralphLoop/AGENTS.md` plus one extra `## Beads workflow` section appended. The `<!-- CUSTOMIZE -->` markers stay in place — this is the reference template; users see it customized after Step 6 of `SETUP_BEADS.md` runs against their target project. Must remain under ~60 lines after the `Beads workflow` section is added.

- [ ] **Step 1: Create `ralphLoopBeads/AGENTS.md` with this exact content**

````markdown
# AGENTS.md — Operational Guide

## Source Directories

<!-- CUSTOMIZE: replace with your project's actual source directories -->
- Main source: `src/`
- Shared utilities: `src/lib/`

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

## Beads workflow

```bash
bd ready --json                     # ready-to-claim issues
bd show <id>                        # full issue detail
bd update <id> --claim              # claim an issue
bd close <id> --reason "..."        # close with reasoning
bd dep add <child> <parent>         # link dependency
```
````

- [ ] **Step 2: Confirm the new section is present**

```bash
grep -n '^## Beads workflow$' ralphLoopBeads/AGENTS.md
```

Expected: a single match.

- [ ] **Step 3: Confirm the file stays under the ~60-line cap**

```bash
wc -l ralphLoopBeads/AGENTS.md
```

Expected: ≤ 60 lines. The reference content above is well within that.

- [ ] **Step 4: Confirm prefix parity with markdown track (lines before `## Beads workflow` match `ralphLoop/AGENTS.md` exactly)**

```bash
diff ralphLoop/AGENTS.md <(sed -n '1,/^## Beads workflow$/{ /^## Beads workflow$/!p; }' ralphLoopBeads/AGENTS.md | sed '${/^$/d}')
```

Expected: no output. The lines before the new section are byte-identical to `ralphLoop/AGENTS.md`. (The `sed` trims a trailing blank line that would otherwise appear from the section split — adjust if your platform's `sed` behaves differently; if so, just visually compare the two files.)

- [ ] **Step 5: Commit**

```bash
git add ralphLoopBeads/AGENTS.md
git commit -m "feat(beads): add ralphLoopBeads AGENTS.md with Beads workflow section"
```

---

## Task 5: Reference example — `ralphLoopBeads/PROMPT_plan.md`

**Files:**
- Create: `ralphLoopBeads/PROMPT_plan.md`

Per spec Section 4 Step 3 / Section 5 "Plan mode — exact `bd` flow." The plan-mode prompt diverges substantially from the markdown track:

- Phase 0c rewritten to read `bd ready --json` + `bd list --json` instead of `IMPLEMENTATION_PLAN.md`.
- Phase 2 maps priority to `-p 0..3` flags.
- Phase 3 issues `bd create` per task and links dependencies with `bd dep add`.
- New sanity check at the top of Phase 0c: if `bd ready --json` errors, halt with a clear `bd init` message.
- New top-level guardrail: append-only. Never close, delete, or reopen issues.
- New end-of-iteration summary printed to stdout: counts + advisory list of orphan issues.

- [ ] **Step 1: Create `ralphLoopBeads/PROMPT_plan.md` with this exact content**

````markdown
# Planning Mode (Beads)

You are an autonomous planning agent. Your job is to study specs and source code, perform gap analysis, and append new issues to the beads issue graph. You do NOT implement anything. You do NOT close, delete, or reopen issues — that is build mode's job. Plan mode is strictly **append-only**.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `ralphLoopBeads/specs/` to understand the full scope of requirements. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Read `ralphLoopBeads/AGENTS.md` for the project's source directory paths and conventions. Then, using parallel subagents, study the existing source directories to understand what is already built. Don't assume anything is missing — search first.

## Phase 0c — Read Current Issue Graph

First, sanity-check that beads is initialized. Run:

```
bd ready --json
```

If it errors (e.g. "no beads database found"), halt with this message and exit:

> The beads database is not initialized. Run `bd init` from the project root and re-run the loop.

Then read the current state of the graph:

```
bd ready --json
bd list --json
```

Understand what is already planned (open), what is in progress, and what is closed. Do NOT assume tasks are missing — they may already exist as open or in-progress issues.

## Phase 1 — Gap Analysis

Compare specs against existing source code AND the existing beads graph:
- What is fully implemented and passing tests?
- What is partially implemented?
- What is completely missing AND not already represented as an open beads issue?
- What is implemented but inconsistent with specs?

## Phase 2 — Prioritize

Map priorities to beads `-p` flags (lower number = higher priority):

- `-p 0` — critical / blocks everything else
- `-p 1` — core functionality (the primary JTBD)
- `-p 2` — important but not blocking
- `-p 3` — polish, edge cases, nice-to-haves

Order by:
1. Dependencies (what must exist before other things can be built)
2. Foundational infrastructure (build system, test harness, core types)
3. Core functionality (the primary JTBD)
4. Edge cases and error handling
5. Polish and refinement

## Phase 3 — Create Issues (append-only)

For each missing task, run:

```
bd create "Short title" -p N -d "Description with definition of done"
```

Capture the returned issue IDs.

After all issues are created, link dependencies:

```
bd dep add <child-id> <parent-id>
```

Each issue should:
- Be completable in a single agent iteration
- Have a clear definition of done in its description
- Be linked to any prerequisites via `bd dep add`

## Phase 4 — End-of-Iteration Summary

Print a summary to stdout:
- Count of new issues created this iteration
- Count of dependency edges linked this iteration
- Advisory list of *open* issues that no longer appear to map to any spec — DO NOT close them. The user closes manually.

## Rules

9. **Append-only.** Never `bd close`, `bd update --reopen`, `bd delete`, or otherwise mutate existing issues. Build mode owns all lifecycle transitions.
99. Capture the **why** — encode reasoning into issue descriptions, not just the title.
999. Don't assume functionality is missing. Study the source code AND the beads graph thoroughly before creating an issue.
9999. Tasks must be scoped small enough for one iteration — if a task feels large, split it into multiple issues with `bd dep add` linking them.
99999. Do NOT implement anything. Planning only.
999999. Prefer Markdown in issue descriptions. No JSON.
````

- [ ] **Step 2: Confirm the append-only guardrail is the top-priority rule**

```bash
grep -nE '^9\. \*\*Append-only\.\*\*' ralphLoopBeads/PROMPT_plan.md
```

Expected: a single match. The append-only rule must be the lowest-numbered (highest-priority) guardrail per the escalating-`9` convention used in the markdown track.

- [ ] **Step 3: Confirm no plan-mode `bd close` / `bd update --reopen` / `bd delete` instructions slipped in**

```bash
grep -nE 'bd (close|delete|update [^ ]+ --reopen)' ralphLoopBeads/PROMPT_plan.md && echo "BAD: plan mode must not mutate existing issues" || echo "OK"
```

Expected: `OK`. Plan mode must contain zero references to the closing/reopening/deleting `bd` verbs.

- [ ] **Step 4: Confirm the `bd init` halt message is present**

```bash
grep -n 'Run `bd init` from the project root' ralphLoopBeads/PROMPT_plan.md
```

Expected: a single match inside Phase 0c.

- [ ] **Step 5: Confirm all paths use `ralphLoopBeads/`**

```bash
grep -n 'ralphLoop/' ralphLoopBeads/PROMPT_plan.md && echo "BAD: stray ralphLoop/ path" || echo "OK"
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add ralphLoopBeads/PROMPT_plan.md
git commit -m "feat(beads): add ralphLoopBeads PROMPT_plan.md (append-only, bd-driven)"
```

---

## Task 6: Reference example — `ralphLoopBeads/PROMPT_build.md`

**Files:**
- Create: `ralphLoopBeads/PROMPT_build.md`

Per spec Section 4 Step 4 / Section 5 "Build mode — exact `bd` flow." Divergences from the markdown track:

- Phase 0c rewritten: check `bd list --status in_progress --json` first and resume any claimed issues before querying `bd ready --json`. This is the self-recovery mechanism for crashed iterations.
- Phase 1 takes ownership via `bd update <id> --claim`.
- Phase 4 closes the issue with `bd close <id> --reason "..."` and includes `.beads/` in the commit.
- Phase 0c sanity check: if `bd ready --json` errors, halt with the same `bd init` message as plan mode.
- Empty-ready-set rule: if `bd ready --json` returns `[]` and no in-progress claims exist, log "No ready work — exiting" and `exit 0`.

- [ ] **Step 1: Create `ralphLoopBeads/PROMPT_build.md` with this exact content**

````markdown
# Building Mode (Beads)

You are an autonomous building agent. Each iteration you pick one issue from the beads graph, implement it completely, validate it, close the issue with a reason, and commit. Then you exit so the next iteration starts with a fresh context.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `ralphLoopBeads/specs/` to understand requirements for the current work. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Read `ralphLoopBeads/AGENTS.md` for the project's source directory paths, build commands, and conventions. Then, using parallel subagents, study the existing source directories to understand what is already built. Don't assume not implemented — search the codebase first.

## Phase 0c — Resume or Select

First, sanity-check that beads is initialized:

```
bd ready --json
```

If it errors (e.g. "no beads database found"), halt with this message and exit:

> The beads database is not initialized. Run `bd init` from the project root and re-run the loop.

Then check for in-progress claims **you** (this loop) already own — they represent a previous iteration that crashed mid-task:

```
bd list --status in_progress --json
```

If any in-progress issues exist that this loop claimed in a prior iteration, **resume those first**. Only after the in-progress set is empty do you query ready work:

```
bd ready --json
```

If `bd ready --json` returns `[]` and no in-progress issues exist, log `No ready work — exiting` to stdout and `exit 0`. The bash loop will spin; the user runs plan mode (or closes blockers manually) to unstick.

Otherwise, pick the highest-priority issue (lowest `-p` number) you can fully complete this iteration. Get full context:

```
bd show <id>
```

## Phase 1 — Claim the Task

Take ownership of the chosen issue:

```
bd update <id> --claim
```

## Phase 2 — Implement

1. Investigate the relevant source code using parallel subagents before writing anything
2. Implement the task completely — no placeholders, no stubs, no TODOs
3. If functionality is missing then it's your job to add it
4. Follow patterns documented in `ralphLoopBeads/AGENTS.md`

## Phase 3 — Validate

Run the validation commands from `ralphLoopBeads/AGENTS.md` using only 1 subagent for build/tests (serialized backpressure):
- Build must pass
- Tests must pass
- Type checking must pass
- Linting must pass

If validation fails, fix the issue and re-validate. Do not commit broken code. The beads issue stays `in_progress`; if the iteration crashes, the next iteration's Phase 0c picks it up automatically.

## Phase 4 — Close, Commit, and Update

1. Close the beads issue with a reason that captures the **why**:
   ```
   bd close <id> --reason "<one-line summary suitable for a commit message>"
   ```
2. Update `ralphLoopBeads/AGENTS.md` with operational learnings if you discovered something useful (keep it under ~60 lines total).
3. Stage `.beads/` together with the code paths you changed:
   ```
   git add .beads/ <code-paths>
   ```
4. Create a git commit with a descriptive message that captures the **why**.
5. Create a semver git tag (`0.0.x`) if the build is clean.
6. Exit cleanly so the loop can restart with a fresh context.

## Guardrails

9. Capture the **why** in commit messages and `bd close --reason` text — document reasoning, not just what changed.

99. Single sources of truth — no migrations, no adapters, no compatibility shims. Fix unrelated test failures you encounter.

999. Create git tags for clean builds using semver `0.0.x` format.

9999. Add extra logging if needed for debugging. Remove it when the issue is resolved.

99999. The beads graph is the only plan. Status and progress live in beads — never in `AGENTS.md`. If you discover new work, file it as a new issue with `bd create` (and link with `bd dep add` if dependent on the current one).

999999. Update `ralphLoopBeads/AGENTS.md` with operational learnings — but keep it brief. ~60 lines max.

9999999. Resolve bugs or document them — even if unrelated to your current task. If you find a bug, either fix it or file a new beads issue with `bd create`.

99999999. If functionality is missing then it's your job to add it. No placeholders, no stubs, no "TODO: implement later". Implement completely or don't touch it.

999999999. Always commit `.beads/` alongside code changes. The beads database is shared state — local-only updates lose information.

9999999999. If you find spec inconsistencies, resolve them using an Opus subagent with Ultrathink. Document the resolution in the relevant beads issue's close reason.

99999999999. `AGENTS.md` is operational only — "how to build and test", not "what was built". Status and progress live in beads.

## Subagent Strategy

- Use the main context as a **scheduler** — don't do expensive work in main context
- Fan out **parallel subagents** for file reads, searches, and investigation — one per file, up to ~10 concurrent (Pro subscription rate limits apply)
- For trivially small directories (< 5 files), skip subagents and read directly
- Use **only 1 subagent for build/tests** — serialized backpressure prevents parallel builds from masking failures
- Use **Opus subagents with Ultrathink** sparingly for complex reasoning, debugging, and architectural decisions
````

- [ ] **Step 2: Confirm the in-progress resume rule precedes the ready-work query**

```bash
grep -n -E 'bd list --status in_progress --json|bd ready --json' ralphLoopBeads/PROMPT_build.md
```

Expected: the first `bd list --status in_progress --json` line appears at a smaller line number than the first `bd ready --json` line **inside Phase 0c**. (The `bd ready --json` sanity-check at the very top of Phase 0c is a separate, allowed earlier occurrence — it's the init check, not the work query. Visually verify the order: sanity-check → in-progress check → ready query.)

- [ ] **Step 3: Confirm the empty-ready-set exit message is present**

```bash
grep -n 'No ready work — exiting' ralphLoopBeads/PROMPT_build.md
```

Expected: a single match.

- [ ] **Step 4: Confirm the close + commit shape**

```bash
grep -n 'bd close <id> --reason' ralphLoopBeads/PROMPT_build.md
grep -n 'git add .beads/ <code-paths>' ralphLoopBeads/PROMPT_build.md
```

Expected: each grep finds at least one line. The `.beads/` directory MUST be explicitly staged alongside the code paths in Phase 4.

- [ ] **Step 5: Confirm all paths use `ralphLoopBeads/`**

```bash
grep -n 'ralphLoop/' ralphLoopBeads/PROMPT_build.md && echo "BAD: stray ralphLoop/ path" || echo "OK"
```

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add ralphLoopBeads/PROMPT_build.md
git commit -m "feat(beads): add ralphLoopBeads PROMPT_build.md (resume + claim + close)"
```

---

## Task 7: Skill files for the beads track

**Files:**
- Create: `skills/setup-ralph-loop-beads.md` (portable copy users can drop into `.claude/commands/`)
- Create: `.claude/skills/setup-ralph-loop-beads/SKILL.md` (this-repo skill with full frontmatter)

Both follow the shape of the existing setup-ralph-loop skill files. The portable copy is bare instructions (matches `skills/setup-ralph-loop.md`); the this-repo copy has YAML frontmatter (matches `.claude/skills/setup-ralph-loop/SKILL.md`). Both fetch `SETUP_BEADS.md` rather than `SETUP.md` and scaffold `ralphLoopBeads/`. Both mention the `bd` install precondition explicitly so the user is not surprised when Step 0 halts.

- [ ] **Step 1: Create `skills/setup-ralph-loop-beads.md` with this exact content**

````markdown
Fetch the Ralph Loop (Beads track) SETUP_BEADS.md from https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md

Follow every step in that file to scaffold a `ralphLoopBeads/` directory in this repository. SETUP_BEADS.md includes a `bd`-installed pre-flight check (Step 0), project analysis, all templates, and a verification step — follow it end to end.

This track requires the `bd` (beads) CLI to be installed on the machine running the loop. If it is not installed, Step 0 will halt with install instructions; install `bd` and re-run.

After all steps are complete, commit the scaffolded files (including `.beads/`).
````

- [ ] **Step 2: Create `.claude/skills/setup-ralph-loop-beads/SKILL.md` with this exact content**

````markdown
---
name: setup-ralph-loop-beads
description: "Fetch the Ralph Loop (Beads track) SETUP_BEADS.md from https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md and scaffold a ralphLoopBeads/ directory in the current project. Use when the user wants to set up or install the beads-driven Ralph Loop. Requires the bd CLI (beads) to be installed."
---

Fetch the Ralph Loop (Beads track) SETUP_BEADS.md from https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md

Follow every step in that file to scaffold a `ralphLoopBeads/` directory in this repository. SETUP_BEADS.md includes a `bd`-installed pre-flight check (Step 0), project analysis, all templates, and a verification step — follow it end to end.

This track requires the `bd` (beads) CLI to be installed on the machine running the loop. If it is not installed, Step 0 will halt with install instructions; install `bd` and re-run.

After all steps are complete, commit the scaffolded files (including `.beads/`).
````

- [ ] **Step 3: Confirm both files reference `SETUP_BEADS.md` and `ralphLoopBeads/`, never the markdown-track names**

```bash
grep -n 'SETUP\.md\|ralphLoop/' skills/setup-ralph-loop-beads.md && echo "BAD" || echo "OK (portable)"
grep -n 'SETUP\.md\|ralphLoop/' .claude/skills/setup-ralph-loop-beads/SKILL.md && echo "BAD" || echo "OK (this-repo)"
```

Expected: both print `OK`. Neither file mentions the markdown-track filename or directory.

- [ ] **Step 4: Confirm the this-repo skill has valid frontmatter**

```bash
head -4 .claude/skills/setup-ralph-loop-beads/SKILL.md
```

Expected: opens with `---`, has `name:` and `description:` fields, closes with `---`. The shape matches `.claude/skills/setup-ralph-loop/SKILL.md`.

- [ ] **Step 5: Commit**

```bash
git add skills/setup-ralph-loop-beads.md .claude/skills/setup-ralph-loop-beads/SKILL.md
git commit -m "feat(beads): add setup-ralph-loop-beads skill (portable + this-repo)"
```

---

## Task 8: `SETUP_BEADS.md` — self-contained scaffold doc

**Files:**
- Create: `SETUP_BEADS.md`

This is the largest file. It is a self-contained 10-step scaffold doc with all templates inline, mirroring the shape of `SETUP.md`. It is fetched via the canonical URL by the skill files in Task 7. The user-facing scaffolded directory is `ralphLoopBeads/`.

The templates inlined into `SETUP_BEADS.md` MUST match the reference example you just created in Tasks 1–6. If they drift, users get a different scaffold than what's shown in this repo. The verification task at the end (Task 12) compares them.

- [ ] **Step 1: Create `SETUP_BEADS.md` with this exact content**

`````markdown
# Ralph Loop Setup (Beads Track) — Skill Instructions

You are an autonomous agent scaffolding the beads-driven Ralph Loop into a target project. Execute each step below in order. Where you see `<!-- CUSTOMIZE -->` markers, adapt the content to the target project using information gathered in Step 0. Do NOT leave placeholder commands — detect and fill in real values.

This track uses [beads](https://github.com/steveyegge/beads) (`bd` CLI) — a Dolt-backed issue graph designed for AI coding agents — as the loop's coordination state instead of `IMPLEMENTATION_PLAN.md`. Do NOT create an `IMPLEMENTATION_PLAN.md` file in this track.

## Step 0 — Analyze the target project + pre-flight check

### Pre-flight: verify `bd` is installed

Run `bd --version`. If it fails (e.g. "command not found"), halt setup with this message and do nothing else:

> The beads CLI (`bd`) is not installed. The beads-driven Ralph Loop requires it. Install one of these ways:
>
> - macOS: `brew install beads`
> - Node: `npm install -g @beads/bd`
> - Install script: see https://github.com/steveyegge/beads
>
> Once installed, re-run setup.

Do not proceed past Step 0 if `bd` is missing.

### Analyze the target project

Before creating any files, study the target project to gather information you will need for customization:

1. **Detect language and framework** — look for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, `build.gradle`, `pom.xml`, `CMakeLists.txt`, `.csproj`, etc.
2. **Map source directories** — identify where application source code lives (e.g., `src/`, `app/`, `lib/`, `packages/`, or root-level). Note the main source directory and any shared utilities directory.
3. **Find build commands** — extract build, run, test, typecheck, and lint commands from the project's config files, scripts, or CI configuration.
4. **Note conventions** — observe naming patterns, file organization, and coding conventions already in use.

Keep this information ready — you will use it to customize `AGENTS.md` in Step 6.

## Step 1 — Create directory structure

```
ralphLoopBeads/
├── loop.sh
├── PROMPT_plan.md
├── PROMPT_build.md
├── PROMPT_specs.md
├── AGENTS.md
├── JTBD.md                   (Job to Be Done — user fills this in)
└── specs/                    (empty directory — specs loop populates it)
```

Plus, at the **project root** (not inside `ralphLoopBeads/`), `bd init` will create `.beads/` in Step 8. Do NOT create `IMPLEMENTATION_PLAN.md`.

## Step 2 — Create loop.sh

Copy verbatim. Make executable with `chmod +x ralphLoopBeads/loop.sh`.

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

  # Pull rebased so .beads/ stays in sync if another clone is also pushing
  git pull --rebase 2>/dev/null || true

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

The added `git pull --rebase` line keeps `.beads/` synchronized when multiple clones share the issue graph. It is a no-op for solo loops with no remote. **The script never calls `bd` — only the agent does, via the prompts.**

## Step 3 — Create PROMPT_plan.md

Copy verbatim:

````markdown
# Planning Mode (Beads)

You are an autonomous planning agent. Your job is to study specs and source code, perform gap analysis, and append new issues to the beads issue graph. You do NOT implement anything. You do NOT close, delete, or reopen issues — that is build mode's job. Plan mode is strictly **append-only**.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `ralphLoopBeads/specs/` to understand the full scope of requirements. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Read `ralphLoopBeads/AGENTS.md` for the project's source directory paths and conventions. Then, using parallel subagents, study the existing source directories to understand what is already built. Don't assume anything is missing — search first.

## Phase 0c — Read Current Issue Graph

First, sanity-check that beads is initialized. Run:

```
bd ready --json
```

If it errors (e.g. "no beads database found"), halt with this message and exit:

> The beads database is not initialized. Run `bd init` from the project root and re-run the loop.

Then read the current state of the graph:

```
bd ready --json
bd list --json
```

Understand what is already planned (open), what is in progress, and what is closed. Do NOT assume tasks are missing — they may already exist as open or in-progress issues.

## Phase 1 — Gap Analysis

Compare specs against existing source code AND the existing beads graph:
- What is fully implemented and passing tests?
- What is partially implemented?
- What is completely missing AND not already represented as an open beads issue?
- What is implemented but inconsistent with specs?

## Phase 2 — Prioritize

Map priorities to beads `-p` flags (lower number = higher priority):

- `-p 0` — critical / blocks everything else
- `-p 1` — core functionality (the primary JTBD)
- `-p 2` — important but not blocking
- `-p 3` — polish, edge cases, nice-to-haves

Order by:
1. Dependencies (what must exist before other things can be built)
2. Foundational infrastructure (build system, test harness, core types)
3. Core functionality (the primary JTBD)
4. Edge cases and error handling
5. Polish and refinement

## Phase 3 — Create Issues (append-only)

For each missing task, run:

```
bd create "Short title" -p N -d "Description with definition of done"
```

Capture the returned issue IDs.

After all issues are created, link dependencies:

```
bd dep add <child-id> <parent-id>
```

Each issue should:
- Be completable in a single agent iteration
- Have a clear definition of done in its description
- Be linked to any prerequisites via `bd dep add`

## Phase 4 — End-of-Iteration Summary

Print a summary to stdout:
- Count of new issues created this iteration
- Count of dependency edges linked this iteration
- Advisory list of *open* issues that no longer appear to map to any spec — DO NOT close them. The user closes manually.

## Rules

9. **Append-only.** Never `bd close`, `bd update --reopen`, `bd delete`, or otherwise mutate existing issues. Build mode owns all lifecycle transitions.
99. Capture the **why** — encode reasoning into issue descriptions, not just the title.
999. Don't assume functionality is missing. Study the source code AND the beads graph thoroughly before creating an issue.
9999. Tasks must be scoped small enough for one iteration — if a task feels large, split it into multiple issues with `bd dep add` linking them.
99999. Do NOT implement anything. Planning only.
999999. Prefer Markdown in issue descriptions. No JSON.
````

## Step 4 — Create PROMPT_build.md

Copy verbatim:

````markdown
# Building Mode (Beads)

You are an autonomous building agent. Each iteration you pick one issue from the beads graph, implement it completely, validate it, close the issue with a reason, and commit. Then you exit so the next iteration starts with a fresh context.

## Phase 0a — Study Specs

Using parallel subagents (one per file, up to ~10 concurrent), study every file in `ralphLoopBeads/specs/` to understand requirements for the current work. For small directories (< 5 files), read them directly without subagents.

## Phase 0b — Study Source Code

Read `ralphLoopBeads/AGENTS.md` for the project's source directory paths, build commands, and conventions. Then, using parallel subagents, study the existing source directories to understand what is already built. Don't assume not implemented — search the codebase first.

## Phase 0c — Resume or Select

First, sanity-check that beads is initialized:

```
bd ready --json
```

If it errors (e.g. "no beads database found"), halt with this message and exit:

> The beads database is not initialized. Run `bd init` from the project root and re-run the loop.

Then check for in-progress claims **you** (this loop) already own — they represent a previous iteration that crashed mid-task:

```
bd list --status in_progress --json
```

If any in-progress issues exist that this loop claimed in a prior iteration, **resume those first**. Only after the in-progress set is empty do you query ready work:

```
bd ready --json
```

If `bd ready --json` returns `[]` and no in-progress issues exist, log `No ready work — exiting` to stdout and `exit 0`. The bash loop will spin; the user runs plan mode (or closes blockers manually) to unstick.

Otherwise, pick the highest-priority issue (lowest `-p` number) you can fully complete this iteration. Get full context:

```
bd show <id>
```

## Phase 1 — Claim the Task

Take ownership of the chosen issue:

```
bd update <id> --claim
```

## Phase 2 — Implement

1. Investigate the relevant source code using parallel subagents before writing anything
2. Implement the task completely — no placeholders, no stubs, no TODOs
3. If functionality is missing then it's your job to add it
4. Follow patterns documented in `ralphLoopBeads/AGENTS.md`

## Phase 3 — Validate

Run the validation commands from `ralphLoopBeads/AGENTS.md` using only 1 subagent for build/tests (serialized backpressure):
- Build must pass
- Tests must pass
- Type checking must pass
- Linting must pass

If validation fails, fix the issue and re-validate. Do not commit broken code. The beads issue stays `in_progress`; if the iteration crashes, the next iteration's Phase 0c picks it up automatically.

## Phase 4 — Close, Commit, and Update

1. Close the beads issue with a reason that captures the **why**:
   ```
   bd close <id> --reason "<one-line summary suitable for a commit message>"
   ```
2. Update `ralphLoopBeads/AGENTS.md` with operational learnings if you discovered something useful (keep it under ~60 lines total).
3. Stage `.beads/` together with the code paths you changed:
   ```
   git add .beads/ <code-paths>
   ```
4. Create a git commit with a descriptive message that captures the **why**.
5. Create a semver git tag (`0.0.x`) if the build is clean.
6. Exit cleanly so the loop can restart with a fresh context.

## Guardrails

9. Capture the **why** in commit messages and `bd close --reason` text — document reasoning, not just what changed.

99. Single sources of truth — no migrations, no adapters, no compatibility shims. Fix unrelated test failures you encounter.

999. Create git tags for clean builds using semver `0.0.x` format.

9999. Add extra logging if needed for debugging. Remove it when the issue is resolved.

99999. The beads graph is the only plan. Status and progress live in beads — never in `AGENTS.md`. If you discover new work, file it as a new issue with `bd create` (and link with `bd dep add` if dependent on the current one).

999999. Update `ralphLoopBeads/AGENTS.md` with operational learnings — but keep it brief. ~60 lines max.

9999999. Resolve bugs or document them — even if unrelated to your current task. If you find a bug, either fix it or file a new beads issue with `bd create`.

99999999. If functionality is missing then it's your job to add it. No placeholders, no stubs, no "TODO: implement later". Implement completely or don't touch it.

999999999. Always commit `.beads/` alongside code changes. The beads database is shared state — local-only updates lose information.

9999999999. If you find spec inconsistencies, resolve them using an Opus subagent with Ultrathink. Document the resolution in the relevant beads issue's close reason.

99999999999. `AGENTS.md` is operational only — "how to build and test", not "what was built". Status and progress live in beads.

## Subagent Strategy

- Use the main context as a **scheduler** — don't do expensive work in main context
- Fan out **parallel subagents** for file reads, searches, and investigation — one per file, up to ~10 concurrent (Pro subscription rate limits apply)
- For trivially small directories (< 5 files), skip subagents and read directly
- Use **only 1 subagent for build/tests** — serialized backpressure prevents parallel builds from masking failures
- Use **Opus subagents with Ultrathink** sparingly for complex reasoning, debugging, and architectural decisions
````

## Step 5 — Create PROMPT_specs.md

Copy verbatim:

```markdown
# Spec-Writing Mode

You are writing specification files for an autonomous coding agent. Your job is to turn a Job to Be Done (JTBD) into clear, behavioral specs that any team could implement on any stack.

## Phase 0 — Orient

1. Read `ralphLoopBeads/JTBD.md` to understand what the user wants built
2. Study the existing `ralphLoopBeads/specs/` directory using parallel subagents to understand what specs already exist
3. Study `ralphLoopBeads/AGENTS.md` for project context and conventions

## Phase 1 — Break Down the JTBD

1. Identify the Job to Be Done from `ralphLoopBeads/JTBD.md`
2. Break the JTBD into **topics of concern**
3. Apply the **one-sentence scope test**: if you can't describe a topic in one sentence without "and", split it further
4. Each topic becomes one spec file

## Phase 2 — Write Specs

For each topic of concern, create a spec file at `ralphLoopBeads/specs/TOPIC_NAME.md`.

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

This is the **only file that must be fully adapted** to the target project. Use the information gathered in Step 0 to fill in every section with real commands and paths. Do NOT leave placeholder comments or `<!-- CUSTOMIZE -->` markers in the final file. If the project has no command for a category (e.g., no type checker), omit that line entirely. Must stay under ~60 lines total.

Template structure (fill in all sections using Step 0 findings; the `## Beads workflow` section at the end is fixed — copy it verbatim):

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

    ## Beads workflow

    ```bash
    bd ready --json                     # ready-to-claim issues
    bd show <id>                        # full issue detail
    bd update <id> --claim              # claim an issue
    bd close <id> --reason "..."        # close with reasoning
    bd dep add <child> <parent>         # link dependency
    ```

## Step 7 — Create JTBD.md

Create `ralphLoopBeads/JTBD.md` with placeholder content for the user to fill in before running specs mode:

```markdown
# Job to Be Done

<!-- Describe WHAT you want built here. Focus on outcomes, not implementation. -->
<!-- Example: "Users can sign up, log in, and manage their profile." -->
<!-- The specs loop will break this into detailed behavioral specs. -->
```

## Step 8 — Initialize beads

This step replaces "create empty IMPLEMENTATION_PLAN.md" from the markdown track. Do NOT create `IMPLEMENTATION_PLAN.md`.

From the project root (the directory **containing** `ralphLoopBeads/`, not inside it), run:

```
bd init
```

This creates `.beads/` at the project root with default mode (not `--stealth`, not `--contributor`).

Verify:

1. `.beads/` directory exists where you ran `bd init`.
2. `bd ready --json` returns `[]` (empty graph) without error.
3. Stage the directory so it is tracked:

   ```
   git add .beads/
   ```

The `.beads/` directory is intended to be committed.

## Step 9 — Verify setup

Confirm the scaffolding is correct:

1. All files from Step 1 exist in `ralphLoopBeads/`.
2. `ralphLoopBeads/loop.sh` is executable (`chmod +x`).
3. `ralphLoopBeads/loop.sh` contains the `git pull --rebase 2>/dev/null || true` line (and does NOT contain any `bd` invocations — only the agent calls `bd`).
4. `ralphLoopBeads/AGENTS.md` contains **real commands** — not placeholder comments. If any section still has `<!-- CUSTOMIZE -->` or `# <your ... command>`, go back and fill it in using Step 0 findings.
5. `ralphLoopBeads/AGENTS.md` ends with a `## Beads workflow` section containing the `bd` command reference.
6. All `ralphLoopBeads/PROMPT_*.md` files exist and reference `ralphLoopBeads/` paths (not `ralphLoop/`).
7. `ralphLoopBeads/specs/` directory exists.
8. `.beads/` exists at the project root and `bd ready --json` runs without error.
9. `IMPLEMENTATION_PLAN.md` was NOT created in `ralphLoopBeads/`.

## Step 10 — Tell the user what to do next

After scaffolding is complete, tell the user:

1. **Edit `ralphLoopBeads/JTBD.md`** — describe what you want the loop to build.
2. **Run specs mode**: `bash ralphLoopBeads/loop.sh specs 2` — generates behavioral specs from the JTBD.
3. **Review specs** in `ralphLoopBeads/specs/` — adjust if needed.
4. **Run planning mode**: `bash ralphLoopBeads/loop.sh plan 2` — appends issues to the beads graph.
5. **Inspect the plan** with `bd ready` (next ready-to-claim issues) or `bd list` (full graph). Use `bd show <id>` for any individual issue.
6. **Run build mode**: `bash ralphLoopBeads/loop.sh build` — autonomously claims, implements, validates, and closes issues.
7. **Override model** if needed: `RALPH_MODEL=sonnet bash ralphLoopBeads/loop.sh build`.

**Inspecting and managing the beads graph manually:**

- `bd ready` — see what the loop will pick next
- `bd show <id>` — inspect any issue
- `bd close <id>` — retire stale work; plan mode is append-only and will not close issues automatically
- `bd update <id> --reopen` — bring something back if you closed it by accident

**Resetting the plan:** there is no automated reset path. To start over, manually `bd close` every open issue (or delete `.beads/` and re-run `bd init`, losing history).

**Sandboxing (recommended):** the loop runs Claude with `--dangerously-skip-permissions`, which means every `bd` call and every shell command also runs unsandboxed. Running the loop in an isolated environment (Docker, E2B, Modal, Daytona, or a disposable VM) is strongly recommended to control blast radius. It is not strictly required — users on dedicated dev machines who trust their prompts may opt out — but it is the safe default.
`````

> **Note on nested fences:** the inlined `PROMPT_plan.md` and `PROMPT_build.md` blocks above use 4-backtick (` ```` `) outer fences so their inner triple-backtick `bd` command examples stay literal. The `PROMPT_specs.md`, `loop.sh`, `JTBD.md`, and `AGENTS.md` blocks use plain triple-backtick fences. Copy the content between the fences verbatim — no escape sequences, no transformations. The verification steps below catch drift either way.

- [ ] **Step 2: Confirm the file is self-contained (no external fetches required by the user)**

```bash
grep -n 'curl\|wget\|fetch from another file' SETUP_BEADS.md && echo "BAD: setup must be self-contained" || echo "OK"
```

Expected: `OK`. There are no external fetch instructions — every template is inline.

- [ ] **Step 3: Confirm Step 0 contains the bd pre-flight halt message**

```bash
grep -n '^### Pre-flight: verify .bd. is installed' SETUP_BEADS.md
grep -n 'brew install beads' SETUP_BEADS.md
grep -n 'npm install -g @beads/bd' SETUP_BEADS.md
```

Expected: each grep finds at least one match.

- [ ] **Step 4: Confirm the inlined `loop.sh` matches the reference `ralphLoopBeads/loop.sh` exactly**

Extract the inlined loop.sh from SETUP_BEADS.md (the only `bash` fenced block under `## Step 2`) and diff it against `ralphLoopBeads/loop.sh`:

```bash
awk '
  /^## Step 2 — Create loop.sh/ {step2=1; next}
  step2 && /^## Step 3/ {exit}
  step2 && /^```bash$/ {inblock=1; next}
  step2 && inblock && /^```$/ {inblock=0; next}
  step2 && inblock {print}
' SETUP_BEADS.md > /tmp/setup_beads_loop.sh
diff /tmp/setup_beads_loop.sh ralphLoopBeads/loop.sh
```

Expected: no output (files identical).

- [ ] **Step 5: Confirm the inlined PROMPT files match the reference copies**

```bash
# PROMPT_specs.md (Step 5 of SETUP_BEADS.md)
awk '
  /^## Step 5 — Create PROMPT_specs.md/ {s=1; next}
  s && /^## Step 6/ {exit}
  s && /^```markdown$/ {inblock=1; next}
  s && inblock && /^```$/ {inblock=0; next}
  s && inblock {print}
' SETUP_BEADS.md > /tmp/setup_beads_prompt_specs.md
diff /tmp/setup_beads_prompt_specs.md ralphLoopBeads/PROMPT_specs.md
```

Expected: no output.

Repeat the same check for `PROMPT_plan.md` (Step 3 of `SETUP_BEADS.md` vs `ralphLoopBeads/PROMPT_plan.md`) and `PROMPT_build.md` (Step 4 vs `ralphLoopBeads/PROMPT_build.md`). If `awk` extraction is brittle on your platform, the simplest fallback is to open both the inlined block in `SETUP_BEADS.md` and the reference file side by side and confirm visually. Drift here breaks user trust in the reference example.

- [ ] **Step 6: Confirm `IMPLEMENTATION_PLAN.md` is explicitly excluded**

```bash
grep -n -i 'IMPLEMENTATION_PLAN' SETUP_BEADS.md
```

Expected: every match is a "do NOT create" instruction. There must be no instruction to create the file.

- [ ] **Step 7: Commit**

```bash
git add SETUP_BEADS.md
git commit -m "feat(beads): add SETUP_BEADS.md self-contained scaffold doc"
```

---

## Task 9: `documentation/ralph-loop-beads-design.md` — design rationale

**Files:**
- Create: `documentation/ralph-loop-beads-design.md`

Per spec Section 6: mirrors the existing design doc's section structure (Key Design Decisions, Critical Principles, Prompt Engineering Patterns, File Roles), with beads-specific content. Rationale only — `SETUP_BEADS.md` is the authoritative scaffold doc, so this file links to it for instructions.

Includes the five rationale topics from the spec:
1. Issue database vs. markdown plan — why this track exists.
2. Append-only planning — the philosophical shift from "plan is disposable."
3. Self-recovery via in-progress claim check — edge case 2 elevated to a design principle.
4. `git pull --rebase` before each iteration — edge case 3 rationale.
5. Specs stay markdown — why beads does not go all the way down.

Also documents the choice (made in this plan) to ship `ralphLoopBeads/` without a real `.beads/` directory.

- [ ] **Step 1: Create `documentation/ralph-loop-beads-design.md` with this exact content**

````markdown
# Ralph Loop (Beads Track) — Design Reference

Design rationale, principles, and prompt engineering patterns behind the beads-driven Ralph Loop. For setup instructions, see `SETUP_BEADS.md` at the repo root. For the original markdown-track rationale, see `ralph-loop-design.md` in this directory — most of those principles still apply and are not duplicated here.

This track is a **parallel** alternative to the markdown track, not a replacement. Both coexist. Choose whichever fits your workflow.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Coordination state | `bd` issue graph (`.beads/`) | Hash-based IDs prevent merge collisions across clones; structured queries (`bd ready`, `bd dep add`) are richer than markdown headings. |
| Plan-mode lifecycle | Strictly append-only | The plan grows monotonically. Build mode owns close/claim/reopen. Prevents plan and build mode from racing on the same issue. |
| Build-mode resume | Check own in-progress claims first | If an iteration crashes after `bd update --claim` but before `bd close`, the next iteration finds and finishes the work automatically — no human intervention. |
| Empty ready set | Build mode exits 0 with "No ready work" | The bash loop will spin idle; the user runs plan mode (or closes blockers manually) to unstick. No silent thrashing. |
| `loop.sh` and `bd` | `loop.sh` never calls `bd` | The agent issues every `bd` command via the prompts. Mirrors the markdown-track property where `loop.sh` doesn't write `IMPLEMENTATION_PLAN.md`. The loop stays mode-agnostic. |
| `git pull --rebase` per iteration | Added to `loop.sh` (vs. markdown track) | `.beads/` is genuinely shared state. Cheaper to rebase eagerly than fix conflicts after-the-fact. No-op for solo loops. |
| Specs format | Stay markdown | Specs are write-rarely, read-often, human-edited. Beads is overkill for a behavioral description with no lifecycle. |
| `IMPLEMENTATION_PLAN.md` | Not created | Beads is the only plan. Two sources of truth would be the worst possible outcome. |
| Sandboxing posture | Strongly recommended, not enforced | Section 9 of the spec: dual-use disclaimer. Users on disposable VMs / dedicated dev machines may opt out; the README and `SETUP_BEADS.md` phrase it as "recommended," never "required." |
| `bd init` mode | Default (not `--stealth`, not `--contributor`) | Single-claimant solo loops are the assumed shape. Multi-claimant coordination is out of scope for this track. |

---

## Critical Principles

1. **Plan mode is monotonic.** Each plan iteration only adds. Closing happens in build mode (when work completes) or by the user (when scope changes). This is the biggest behavioral difference from the markdown track, where the plan is rewritten in place every planning iteration.
2. **Self-recovery is the in-progress check.** A crashed iteration leaves an `in_progress` claim. The next iteration's Phase 0c finds it and finishes the work before pulling new ready items. No manual intervention needed.
3. **The loop is still the agent.** `loop.sh` orchestrates iterations; the agent (Claude) issues every `bd` call. Tuning happens by editing `PROMPT_*.md`, never by adding logic to `loop.sh`. This is the same property the markdown track has — preserving it keeps both tracks reasoning-compatible.
4. **`.beads/` is committed alongside code.** Always. Build mode's Phase 4 stages both. A code commit without the matching `.beads/` update means the issue graph silently drifts from reality.
5. **Append-only is a discipline, not a guarantee.** Beads doesn't enforce it; the prompt does. If the plan-mode prompt is wrong, the agent could close issues. The `9.` (top-priority) guardrail in `PROMPT_plan.md` exists for this reason.
6. **Sandboxing is suggested, not enforced.** The agent runs with `--dangerously-skip-permissions`; every `bd` call and shell command inherits that. A sandbox is the right default but not a hard requirement — users own that decision.
7. **No automated reset.** Wiping the plan means closing every open issue manually (or deleting `.beads/` and re-initializing, losing history). This is friction by design — the markdown track's "delete and regenerate" pattern doesn't carry over.

---

## Prompt Engineering Patterns

### Sanity check at the top of Phase 0c

Both `PROMPT_plan.md` and `PROMPT_build.md` open Phase 0c with `bd ready --json` as a "is the database alive?" probe. If it errors, both halt with the same `Run bd init from the project root` message. This catches user error (forgot Step 8, deleted `.beads/`) before the agent does anything wasteful.

### Resume-before-pull

Build mode's Phase 0c always queries `bd list --status in_progress --json` before `bd ready --json`. This is the load-bearing line for self-recovery: if a previous iteration crashed after `bd update --claim`, the next iteration picks the same issue back up. Without this, claimed-but-not-closed issues would block ready work indefinitely.

### Empty ready set → exit 0

If `bd ready --json` returns `[]` and there are no in-progress claims, build mode logs "No ready work — exiting" and exits cleanly. The bash loop continues to spin (`MAX_ITERS=0` is the default), which is fine — successive iterations are cheap and a human running plan mode will unstick the queue.

### Append-only as the top-priority guardrail

`PROMPT_plan.md` makes the append-only rule the lowest-numbered (highest-priority) entry in its Rules section. The escalating-`9` numbering convention from the markdown track signals criticality to the model. The first thing the model reads in Rules is "never close, delete, or reopen."

### `.beads/` in every commit

Build mode's Phase 4 explicitly stages `.beads/` together with code paths. The guardrail at the `999999999` priority restates this. Local-only beads updates lose information across iterations and across clones; the rule exists to prevent that.

---

## File Roles

### `SETUP_BEADS.md`

The authoritative scaffold doc. Self-contained (every template inlined). Fetched by `skills/setup-ralph-loop-beads.md` and `.claude/skills/setup-ralph-loop-beads/SKILL.md` from the canonical raw URL. Mirrors `SETUP.md`'s 10-step shape with five steps diverging (0, 1, 2, 3, 4, 8, 9, 10 — see Section 4 of the design spec for the per-step diff).

### `ralphLoopBeads/` (this repo)

Reference example only. Shows users browsing this repo what a scaffolded directory looks like. **Does not contain a real `.beads/` directory** — that would require `bd` on every contributor's machine and would bloat the repo with synthetic test issues. Users running setup get a real `.beads/` from Step 8 of `SETUP_BEADS.md`.

### `ralphLoopBeads/PROMPT_plan.md`

Append-only planning. Reads `bd ready --json` and `bd list --json` in Phase 0c, gap-analyzes, creates new issues with `bd create -p N -d "..."`, links dependencies with `bd dep add`. Never closes anything.

### `ralphLoopBeads/PROMPT_build.md`

Resume-or-select in Phase 0c, claim in Phase 1, implement in Phase 2, validate in Phase 3, close + commit `.beads/` in Phase 4. Owns all lifecycle transitions.

### `ralphLoopBeads/PROMPT_specs.md`

Identical to `ralphLoop/PROMPT_specs.md` except for the `ralphLoopBeads/` path rewrite. Specs stay markdown.

### `ralphLoopBeads/AGENTS.md`

Same template as the markdown track plus a `## Beads workflow` section with the five core `bd` commands the agent calls during build mode. Still under ~60 lines.

### `ralphLoopBeads/loop.sh`

Same script as the markdown track plus one line: `git pull --rebase 2>/dev/null || true` near the top of the `while` body. Never calls `bd`.

### `.beads/` (in user projects)

The single source of truth for the implementation plan in this track. Created by `bd init` during scaffold (Step 8). Committed alongside code on every build-mode iteration. Manually managed for resets — there is no automated wipe.
````

- [ ] **Step 2: Confirm structural parity (Key Design Decisions, Critical Principles, Prompt Engineering Patterns, File Roles all present)**

```bash
grep -n '^## Key Design Decisions$\|^## Critical Principles$\|^## Prompt Engineering Patterns$\|^## File Roles$' documentation/ralph-loop-beads-design.md
```

Expected: four matches in this exact order. The doc mirrors `documentation/ralph-loop-design.md`'s top-level sections.

- [ ] **Step 3: Confirm all five spec-mandated topics are covered**

```bash
grep -niE 'issue database vs|append-only|self-recovery|git pull --rebase|specs stay markdown' documentation/ralph-loop-beads-design.md | wc -l
```

Expected: at least 5 matches (one per topic from spec Section 6, possibly more if the topic is referenced in multiple sections).

- [ ] **Step 4: Commit**

```bash
git add documentation/ralph-loop-beads-design.md
git commit -m "docs(beads): add ralph-loop-beads-design.md rationale doc"
```

---

## Task 10: `README.md` — add beads-track entry points

**Files:**
- Modify: `README.md`

Per spec Section 6 / "README.md edits":

1. Add a one-sentence statement at the top of "What's in this repo" stating both tracks coexist.
2. Add a second paste-one-liner block under the existing one (the "Beads variant" callout).
3. Add four rows to the file table.

The existing README intro stays. The existing one-liner stays. Adding, never editing.

- [ ] **Step 1: Read the current README to confirm exact insertion points**

```bash
sed -n '1,55p' README.md
```

Expected: matches the file content shown in the plan's context-gathering phase. The insertion points used below depend on the exact wording — if the README has drifted, adjust the `Edit` `old_string` values to match what's actually there.

- [ ] **Step 2: Insert the "Beads variant" paste-one-liner block under the existing one-liner**

Use `Edit` with `old_string`:

```
> Fetch https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP.md and follow every step to scaffold a Ralph Loop in this project.

Claude fetches `SETUP.md`, analyzes your project, scaffolds a `ralphLoop/` directory, and fills in your actual build/test/lint commands. One message, no files to copy.
```

Replace with:

```
> Fetch https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP.md and follow every step to scaffold a Ralph Loop in this project.

Claude fetches `SETUP.md`, analyzes your project, scaffolds a `ralphLoop/` directory, and fills in your actual build/test/lint commands. One message, no files to copy.

**Beads variant** (if you want a `bd`-backed issue graph instead of a markdown plan; requires the [`bd` CLI](https://github.com/steveyegge/beads) installed):

> Fetch https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md and follow every step to scaffold a beads-driven Ralph Loop in this project.

This scaffolds a `ralphLoopBeads/` directory and runs `bd init`. The two tracks coexist — pick whichever fits your workflow.
```

- [ ] **Step 3: Add the intro sentence at the top of "What's in this repo"**

Use `Edit` with `old_string`:

```
## What's in this repo

| File | Purpose |
```

Replace with:

```
## What's in this repo

This repo ships two parallel scaffold tracks — the markdown track (`SETUP.md` → `ralphLoop/` with `IMPLEMENTATION_PLAN.md`) and the beads track (`SETUP_BEADS.md` → `ralphLoopBeads/` with a `bd` issue graph). Pick whichever fits your workflow; they coexist.

| File | Purpose |
```

- [ ] **Step 4: Add the four file-table rows**

Use `Edit` with `old_string`:

```
| `documentation/ralph-loop-design.md` | Design rationale and prompt engineering patterns |
```

Replace with:

```
| `documentation/ralph-loop-design.md` | Design rationale and prompt engineering patterns (markdown track) |
| `SETUP_BEADS.md` | Self-contained setup instructions for the beads track, with all templates inline |
| `skills/setup-ralph-loop-beads.md` | Claude Code slash command — copy to enable `/setup-ralph-loop-beads` |
| `ralphLoopBeads/` | Reference example for the beads track (no real `.beads/` shipped — created by `bd init` at scaffold time) |
| `documentation/ralph-loop-beads-design.md` | Design rationale for the beads track |
```

Note that the existing `documentation/ralph-loop-design.md` row is left unchanged except for the appended "(markdown track)" qualifier — needed to disambiguate from the new beads design doc. **If you would prefer to leave that row byte-identical** (to honor the "do not touch markdown track" constraint maximally), drop the qualifier; the constraint applies to track *files*, but the README is explicitly being modified by this task. Either reading is defensible. The qualifier is recommended for clarity but not required.

- [ ] **Step 5: Confirm the four new rows are present and the existing one-liner is intact**

```bash
grep -n 'SETUP_BEADS\.md\|setup-ralph-loop-beads\|ralphLoopBeads' README.md
grep -n 'SETUP\.md and follow every step to scaffold a Ralph Loop' README.md
```

Expected: the first grep finds multiple matches (table rows + new one-liner block + intro sentence). The second grep still finds the original markdown-track one-liner — it must remain.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs(beads): add beads-track entry points to README"
```

---

## Task 11: Final verification — markdown track byte-identical + structural checks

**Files:**
- (no file changes; verification only)

Per spec Section 7 ("Repo-level checks") and the hard constraint at the top of this plan: confirm the existing markdown track was not touched, every new file is present, and structural invariants hold.

- [ ] **Step 1: Confirm markdown-track files are byte-identical to the base branch**

Determine the base commit (the tip of `main` before this plan's first task — find it with `git log --oneline -20` or rely on the branch state). Then:

```bash
git diff main -- SETUP.md ralphLoop/ skills/setup-ralph-loop.md .claude/skills/setup-ralph-loop/SKILL.md documentation/ralph-loop-design.md CLAUDE.md
```

Expected: NO output. If anything in this list shows a diff, revert that change before proceeding — it violates the plan's hard constraint.

- [ ] **Step 2: Confirm every new file from the inventory exists**

```bash
for f in \
  ralphLoopBeads/loop.sh \
  ralphLoopBeads/PROMPT_specs.md \
  ralphLoopBeads/PROMPT_plan.md \
  ralphLoopBeads/PROMPT_build.md \
  ralphLoopBeads/AGENTS.md \
  ralphLoopBeads/JTBD.md \
  ralphLoopBeads/specs/.gitkeep \
  skills/setup-ralph-loop-beads.md \
  .claude/skills/setup-ralph-loop-beads/SKILL.md \
  SETUP_BEADS.md \
  documentation/ralph-loop-beads-design.md; do
  test -e "$f" && echo "OK $f" || echo "MISSING $f"
done
```

Expected: every line begins with `OK`.

- [ ] **Step 3: Confirm `ralphLoopBeads/` does NOT contain a real `.beads/` directory**

```bash
test -d ralphLoopBeads/.beads && echo "BAD: reference example must not ship .beads/" || echo "OK"
```

Expected: `OK`. (If `bd init` was accidentally run inside `ralphLoopBeads/` during development, remove the directory before merging.)

- [ ] **Step 4: Confirm `IMPLEMENTATION_PLAN.md` was not created in `ralphLoopBeads/`**

```bash
test -e ralphLoopBeads/IMPLEMENTATION_PLAN.md && echo "BAD" || echo "OK"
```

Expected: `OK`.

- [ ] **Step 5: Confirm `loop.sh` does not call `bd` anywhere (Section 9 of spec)**

```bash
grep -n '\bbd\b' ralphLoopBeads/loop.sh && echo "BAD: loop.sh must never call bd" || echo "OK"
```

Expected: `OK`.

- [ ] **Step 6: Confirm `AGENTS.md` line count is within the cap**

```bash
wc -l ralphLoopBeads/AGENTS.md
```

Expected: ≤ 60 lines.

- [ ] **Step 7: Re-run the SETUP_BEADS.md ↔ reference parity checks from Task 8 Steps 4 and 5 to catch drift introduced by intervening tasks**

If the diffs from Task 8 Step 4 and Step 5 still produce no output, the inlined templates and the reference example are still in sync. If they drift, fix the inlined `SETUP_BEADS.md` (the reference is authoritative — it's what users see when they browse the repo).

- [ ] **Step 8: Manual end-to-end test (recommended; requires `bd` installed locally)**

Per spec Section 7 "Manual end-to-end test." On a fresh empty git repo (e.g. `mktemp -d` + `git init`):

1. Paste the beads-track one-liner from `README.md` into Claude Code with `bd` installed → confirm `ralphLoopBeads/` is scaffolded with `.beads/` initialized at the project root, no `IMPLEMENTATION_PLAN.md`, all Step 9 verification checks pass.
2. Repeat with `bd` *not* installed → confirm setup halts at Step 0 with the install-options message and nothing is scaffolded.
3. Edit `JTBD.md` → run `bash ralphLoopBeads/loop.sh specs 2` → confirm specs appear in `ralphLoopBeads/specs/`.
4. Run `bash ralphLoopBeads/loop.sh plan 2` → confirm `bd ready --json` returns issues with priorities and dependencies; confirm no `IMPLEMENTATION_PLAN.md` exists.
5. Run `bash ralphLoopBeads/loop.sh build` for one iteration → confirm an issue is claimed, code is implemented, validation passes, issue is closed, `.beads/` is in the commit, exit is clean.
6. Mid-iteration kill plus restart → confirm next iteration resumes the in-progress claim (edge case 2).
7. Drain ready work → confirm loop exits cleanly with "No ready work" (edge case 1).

This step is **strongly recommended** but not blocking if `bd` cannot be installed in the verification environment. The spec acknowledges no automated tests exist for either scaffold.

- [ ] **Step 9: Final commit if any verification fixes were made**

If Steps 1–7 surfaced any drift and you fixed it, commit those fixes:

```bash
git add -A
git commit -m "chore(beads): fix verification-time drift between SETUP_BEADS.md and reference"
```

If no fixes were needed, no commit. The plan is complete.

---

## Self-Review Notes (author's pre-handoff check)

**Spec coverage:** Walked through every section of `documentation/superpowers/specs/2026-05-03-beads-support-design.md`:

- Section 2 Goals — covered: one-liner (Task 10), self-contained setup (Task 8), markdown track untouched (verification Task 11 Step 1), beads-as-source-of-truth (no `IMPLEMENTATION_PLAN.md` anywhere in `ralphLoopBeads/`), specs stay markdown (Task 3 + Step 5 of `SETUP_BEADS.md`).
- Section 3 file inventory — all 12 new files / 1 modified file are tasks. The reference example's `.beads/` row in the spec table is intentionally NOT created (documented in Task 9 design doc).
- Section 4 step-by-step contents — every step is reflected in `SETUP_BEADS.md` content in Task 8.
- Section 5 loop semantics — encoded in `PROMPT_plan.md` (Task 5) and `PROMPT_build.md` (Task 6); edge cases 1, 2, 3, 4, 5, 6 all addressed in prompt content.
- Section 6 entry points — README edits (Task 10), skill files (Task 7), design doc (Task 9).
- Section 7 verification — covered in Task 11; manual end-to-end test included as Step 8.
- Section 9 "Where `bd` calls run" — explicit `bd` grep on `loop.sh` in Task 2 Step 3 and Task 11 Step 5; sandboxing framed as "strongly recommended" not "required" in `SETUP_BEADS.md` Step 10 and design doc.

**Placeholder scan:** No "TBD," "TODO," "implement later," "fill in details," "appropriate error handling," "similar to Task N" patterns. Each task has full file content inlined.

**Type consistency:** No types or method signatures — this is a documentation/scaffold-template change. The `bd` command surface (`bd create`, `bd dep add`, `bd ready --json`, `bd list --status in_progress --json`, `bd update <id> --claim`, `bd close <id> --reason`, `bd show <id>`) is consistent across `PROMPT_plan.md`, `PROMPT_build.md`, `SETUP_BEADS.md` Steps 3/4, and the `## Beads workflow` section in `AGENTS.md`. The `-p 0..3` priority semantics are consistent between plan-mode prompt and design doc.

**Open question for the user:**
- Task 10 Step 4 includes a small qualifier on the existing markdown-track design-doc row in the README (`(markdown track)`). The plan flags this as defensible-either-way; the user may prefer strict no-touch on existing rows. If so, drop that one-character edit.

---

## Execution Handoff

Plan complete and saved to `documentation/superpowers/plans/2026-05-03-beads-support.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best fit when each task is self-contained and verifiable on its own (true here — every task ends with a commit).

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Best fit if you want to watch every step go by and intervene quickly.

**Which approach?**
