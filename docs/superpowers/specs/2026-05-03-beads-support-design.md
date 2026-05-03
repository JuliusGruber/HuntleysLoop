# Beads Support — Design

**Date:** 2026-05-03
**Status:** Approved, ready for implementation planning
**Topic:** Add a parallel scaffold track to HuntleysLoop that uses [beads](https://github.com/steveyegge/beads) (`bd` CLI, an issue database for AI coding agents) as the loop's coordination state, replacing the role of `IMPLEMENTATION_PLAN.md` in the existing markdown track.

---

## 1. Context

HuntleysLoop ships `SETUP.md` — a self-contained, 10-step scaffold doc — that Claude executes against a target project to produce a `ralphLoop/` directory containing a bash loop, prompt files, and a customized `AGENTS.md`. The existing loop uses `IMPLEMENTATION_PLAN.md` as the only coordination mechanism between iterations. Plan mode rewrites it; build mode reads it, picks the top task, implements, validates, commits, exits.

Beads provides a structured alternative: a Dolt-backed, version-controlled issue graph with `bd ready --json` (programmatic ready-work query), `bd dep add` (dependencies), `bd update --claim` / `bd close` (lifecycle), and hash-based IDs (merge-collision-free for multi-agent workflows). It was explicitly built to replace markdown TODO files as agent state.

This design adds a **parallel** beads-driven track without modifying the existing markdown track.

## 2. Goals and non-goals

**Goals**
- Users can paste a single beads-track one-liner into Claude Code and get a fully scaffolded beads-driven Ralph Loop.
- The beads track is self-contained the same way `SETUP.md` is: one fetch, all templates inline.
- The existing markdown track is byte-identical after the change. No incidental edits.
- Beads becomes the source of truth for the implementation plan inside the new track. `IMPLEMENTATION_PLAN.md` does not exist in the beads track.
- JTBD and specs remain markdown files in both tracks.

**Non-goals**
- Replacing or deprecating the existing markdown track. Both tracks coexist.
- Automated CI tests for either scaffold (the existing track has none; this design adds none).
- Migration tooling from markdown plan to beads. Users start fresh.
- Coordinating multiple parallel build loops beyond what beads' hash-based IDs already provide.

## 3. Architecture

Two parallel tracks, mirrored structure. `SETUP_BEADS.md` is the authoritative scaffold doc for the new track and follows the same 10-step shape as `SETUP.md`. `ralphLoopBeads/` is a reference example in this repo. The user-facing scaffolded directory in target projects is also named `ralphLoopBeads/` so a project containing both tracks does not collide.

### File inventory

| New file | Mirrors | Purpose |
|---|---|---|
| `SETUP_BEADS.md` | `SETUP.md` | Self-contained, 10-step beads-track scaffold doc with all templates inline |
| `skills/setup-ralph-loop-beads.md` | `skills/setup-ralph-loop.md` | Portable slash-command skill users copy into their project |
| `.claude/skills/setup-ralph-loop-beads/SKILL.md` | `.claude/skills/setup-ralph-loop/SKILL.md` | This-repo skill that fetches `SETUP_BEADS.md` |
| `ralphLoopBeads/` | `ralphLoop/` | Reference example of a scaffolded beads loop |
| `ralphLoopBeads/loop.sh` | `ralphLoop/loop.sh` | Loop script — same shape; adds `git pull --rebase` before each iteration |
| `ralphLoopBeads/PROMPT_specs.md` | `ralphLoop/PROMPT_specs.md` | Identical (specs remain markdown) |
| `ralphLoopBeads/PROMPT_plan.md` | `ralphLoop/PROMPT_plan.md` | Diverges: produces `bd create` / `bd dep add` calls; append-only |
| `ralphLoopBeads/PROMPT_build.md` | `ralphLoop/PROMPT_build.md` | Diverges: selects via `bd ready --json`; commits include `.beads/` |
| `ralphLoopBeads/AGENTS.md` | `ralphLoop/AGENTS.md` | Same template plus a "Beads workflow" section, still under ~60 lines |
| `ralphLoopBeads/JTBD.md` | `ralphLoop/JTBD.md` | Identical placeholder |
| `ralphLoopBeads/specs/.gitkeep` | `ralphLoop/specs/.gitkeep` | Identical |
| `ralphLoopBeads/.beads/` | *(none — `IMPLEMENTATION_PLAN.md` instead)* | Created by `bd init` during scaffold; checked into git |
| `documentation/ralph-loop-beads-design.md` | `documentation/ralph-loop-design.md` | Beads-track design rationale |
| `README.md` | *edits, not new* | Add a second paste-one-liner block + four rows in the file table |

Files **not** changing: `SETUP.md`, `ralphLoop/`, `skills/setup-ralph-loop.md`, `.claude/skills/setup-ralph-loop/SKILL.md`, `documentation/ralph-loop-design.md`, `CLAUDE.md`.

## 4. SETUP_BEADS.md — step-by-step contents

Same 10-step shape as `SETUP.md`. Steps marked **DIVERGES** differ from the current SETUP.md; the rest are essentially copies. The user-facing scaffolded directory is `ralphLoopBeads/`.

### Step 0 — Analyze the target project + pre-flight check (DIVERGES)
- All existing detection (language, source dirs, build/test/lint commands).
- **New pre-flight at the top:** run `bd --version`. If it fails, halt with a hard stop message that lists the three install options (`brew install beads`, `npm install -g @beads/bd`, install script URL) and instructs the user to install and re-run setup. Do not proceed past Step 0 if `bd` is missing.

### Step 1 — Create directory structure (DIVERGES)
```
ralphLoopBeads/
├── loop.sh
├── PROMPT_plan.md
├── PROMPT_build.md
├── PROMPT_specs.md
├── AGENTS.md
├── JTBD.md
├── .beads/                  (created by bd init in Step 8)
└── specs/
```
No `IMPLEMENTATION_PLAN.md`.

### Step 2 — Create `loop.sh` (DIVERGES)
Same as current `SETUP.md` `loop.sh` plus one added line: `git pull --rebase 2>/dev/null || true` near the top of the `while` body, before the `cat | claude -p` invocation. The reason is that `.beads/` is genuinely shared state — it lives in git, so a divergent clone elsewhere can introduce conflicts that are easier to resolve eagerly than reactively. The existing markdown-track `loop.sh` does not change.

`SCRIPT_DIR`-relative paths and the `PROMPT_FILE` resolution stay identical.

### Step 3 — Create `PROMPT_plan.md` (DIVERGES)
Rewritten for beads. Key changes from the markdown-track prompt:

- **Phase 0a/0b unchanged** (study specs, study source code via parallel subagents).
- **Phase 0c rewritten:** "Read the current beads issue graph: run `bd ready --json` and `bd list --json` to see what's open, in-progress, and closed. Do not assume not implemented — search the source first."
- **Phase 1 (gap analysis) unchanged** in spirit.
- **Phase 2 (prioritize) rewritten:** map priorities to `-p 0..3` flags (0 = highest).
- **Phase 3 rewritten — "Create issues":** for each missing task, run `bd create "Title" -p N -d "<description with definition of done>"`. Capture returned issue IDs. After all issues are created, link dependencies with `bd dep add <child-id> <parent-id>`. **Append-only — never close, delete, or reopen existing issues in plan mode.** Build mode owns lifecycle transitions.
- **End-of-iteration summary** printed to stdout: count of new issues created, count of dependencies linked, list of *open* issues that no longer appear to map to any spec (advisory only — the user closes manually).
- **Sanity check at the top of Phase 0:** run `bd ready --json`; if it errors, halt with a clear message instructing the user to run `bd init` and re-run the loop.
- New top-level guardrail: "Append-only. Never close, delete, or reopen existing issues. Build mode owns lifecycle transitions."

### Step 4 — Create `PROMPT_build.md` (DIVERGES)
Rewritten for beads. Key changes:

- **Phase 0a (specs) unchanged.**
- **Phase 0b (AGENTS.md + source code) unchanged.**
- **Phase 0c rewritten:** "Before checking ready work, run `bd list --status in_progress --json`. If any issues are claimed by you (this loop), resume those first — they represent a previous iteration that crashed mid-task. Only after in-progress is empty, query `bd ready --json` and pick the highest-priority issue you can fully complete this iteration. `bd show <id>` for full context."
- **Phase 1 (select task)** rewritten: after picking, run `bd update <id> --claim` to take ownership.
- **Phase 2 (implement) unchanged.**
- **Phase 3 (validate) unchanged.**
- **Phase 4 (commit) rewritten:**
  1. `bd close <id> --reason "<commit-msg-summary>"`
  2. `git add .beads/ <code-paths>` — commit must include the beads DB updates.
  3. Update `AGENTS.md` operational notes if needed.
  4. Tag (semver `0.0.x`) if the build is clean.
  5. Exit cleanly.
- **Sanity check at the top of Phase 0:** run `bd ready --json`; if it errors, halt with the same `bd init` message.
- **Empty ready set rule:** if `bd ready --json` returns `[]` and there are no in-progress issues claimed by this loop, log "No ready work — exiting" and exit 0. The bash loop will spin; the user runs plan mode (or closes blockers manually) to unstick.

### Step 5 — Create `PROMPT_specs.md`
Identical to current `SETUP.md`. Specs stay markdown.

### Step 6 — Create `AGENTS.md` (DIVERGES, slightly)
Same template as current, plus one extra section appended (still under ~60-line cap):

```
## Beads workflow

bd ready --json          # ready-to-claim issues
bd show <id>             # full issue detail
bd update <id> --claim   # claim an issue
bd close <id> --reason "..."  # close with reasoning
bd dep add <child> <parent>   # link dependency
```

### Step 7 — Create `JTBD.md`
Identical to current `SETUP.md`.

### Step 8 — Initialize beads (DIVERGES — replaces "create empty IMPLEMENTATION_PLAN.md")
- Run `bd init` from the project root (default mode — not `--stealth`, not `--contributor`).
- Verify `.beads/` directory was created.
- Run `bd ready --json` to confirm an empty graph (returns `[]`).
- Run `git add .beads/` so it is tracked. The `.beads/` directory is intended to be committed.

### Step 9 — Verify setup (DIVERGES)
Existing checks plus:
- `.beads/` exists and `bd ready --json` runs without error.
- `AGENTS.md` has the "Beads workflow" section.
- No `IMPLEMENTATION_PLAN.md` was created.
- `loop.sh` contains the `git pull --rebase` line.

### Step 10 — Tell the user what to do next (DIVERGES)
Same instructions as current, plus a short paragraph on inspecting the beads graph manually:
- `bd ready` to see what the loop will pick next.
- `bd show <id>` to inspect any issue.
- `bd close <id>` to retire stale work that plan mode (append-only) will not close on its own.
- A note that wiping and starting over means closing all open issues manually (no automated reset).

## 5. Loop semantics

### Plan mode — exact `bd` flow

```
bd create "Short title" -p <0|1|2|3> -d "<description with definition of done>"
# repeat per task; capture returned IDs
bd dep add <child-id> <parent-id>
# repeat per dependency edge
```
Plan mode never calls `bd close`, `bd update --claim`, or `bd update --reopen`. Strict append-only.

### Build mode — exact `bd` flow

```
bd list --status in_progress --json   # check for previous-iteration claims first
# if any claimed by this loop, resume them first
bd ready --json                       # otherwise query ready work
# pick highest priority (lowest -p number) the agent can fully complete
bd show <id>                          # full context
bd update <id> --claim                # take ownership
# implement + validate (build/test/typecheck/lint)
bd close <id> --reason "<commit-msg-summary>"
git add .beads/ <code-paths>
git commit -m "..."
git tag 0.0.<n>                       # if clean
git push 2>/dev/null || true
exit 0
```

### Edge cases

1. **`bd ready --json` returns `[]` and no in-progress claims.** Build mode exits 0 with "No ready work — exiting." User runs plan mode to unstick.
2. **Validation fails after `--claim` but before `close`.** Issue stays `in_progress`. Self-recovery: next iteration's Phase 0c picks up own in-progress claims first, completes them, then moves to `bd ready`.
3. **Merge conflict on `.beads/`.** Beads' hash-based IDs prevent semantic merge collisions, but on-disk state can still conflict if two clones diverge. Mitigated by `git pull --rebase 2>/dev/null || true` at the top of each loop iteration in `loop.sh`.
4. **Plan mode runs before any specs exist.** Plan mode produces no issues; `bd ready` returns empty; build mode exits cleanly. Same UX as current loop running build before plan.
5. **`bd init` was never run** (user skipped Step 8 or deleted `.beads/`). Phase 0 sanity check (`bd ready --json`) fails; both plan and build prompts halt with a message instructing the user to run `bd init`.
6. **User wants to reset.** Documented in Step 10 — close all open issues manually. No automated reset path.

## 6. Entry points

### `README.md` edits

1. Add a second paste-one-liner block under the existing one:

   > **Beads variant** (if you want a `bd`-backed issue graph instead of a markdown plan):
   > > Fetch https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md and follow every step to scaffold a beads-driven Ralph Loop in this project. Requires `bd` to be installed first.

2. Add four rows to the "What's in this repo" file table: `SETUP_BEADS.md`, `skills/setup-ralph-loop-beads.md`, `ralphLoopBeads/`, `documentation/ralph-loop-beads-design.md`.

3. Add one short sentence at the top of "What's in this repo" stating the two tracks coexist and the user picks which to scaffold.

### Skill files

Both `skills/setup-ralph-loop-beads.md` (portable copy) and `.claude/skills/setup-ralph-loop-beads/SKILL.md` (this-repo) follow the same shape as the existing setup-ralph-loop skill:

- Triggers: "set up beads ralph loop", "setup ralph loop beads", "scaffold beads loop", "/setup-ralph-loop-beads"
- Body: instructions to fetch `SETUP_BEADS.md` from the canonical raw URL and follow every step to scaffold a `ralphLoopBeads/` directory in the user's current project. Includes the `bd`-must-be-installed precondition.

### `documentation/ralph-loop-beads-design.md`

Mirrors the existing design doc's section structure (Key Design Decisions, Critical Principles, Prompt Engineering Patterns, File Roles), with beads-specific content:
- "Issue database vs. markdown plan" — why this track exists.
- "Append-only planning" — the philosophical shift from "plan is disposable."
- "Self-recovery via in-progress claim check" — edge case 2 elevated to a design principle.
- "git pull --rebase before each iteration" — edge case 3 rationale.
- "Specs stay markdown" — why beads does not go all the way down.

This file is rationale only. `SETUP_BEADS.md` is the authoritative scaffold doc.

## 7. Verification

### Manual end-to-end test
On a fresh empty git repo:

1. Paste the beads-track one-liner from `README.md` into Claude Code with `bd` installed → `ralphLoopBeads/` is scaffolded with `.beads/` initialized, no `IMPLEMENTATION_PLAN.md`, all Step 9 verification checks pass.
2. Repeat with `bd` not installed → setup halts at Step 0 with the install-options message; nothing is scaffolded.
3. Edit `JTBD.md` → run `bash ralphLoopBeads/loop.sh specs 2` → specs appear in `ralphLoopBeads/specs/`.
4. Run `bash ralphLoopBeads/loop.sh plan 2` → `bd ready --json` returns issues with priorities and dependencies; no `IMPLEMENTATION_PLAN.md` exists.
5. Run `bash ralphLoopBeads/loop.sh build` for one iteration → an issue is claimed, code is implemented, validation passes, issue is closed, `.beads/` is in the commit, exit is clean.
6. Mid-iteration kill plus restart → next iteration resumes the in-progress claim (edge case 2).
7. Drain ready work → loop exits cleanly with "No ready work" (edge case 1).

### Static checks against scaffold output
- `ralphLoopBeads/AGENTS.md` is under ~60 lines after scaffolding.
- `ralphLoopBeads/loop.sh` is executable and contains the `git pull --rebase` line.
- All `PROMPT_*.md` files reference `ralphLoopBeads/` paths, not `ralphLoop/`.
- No `<!-- CUSTOMIZE -->` markers remain.

### Repo-level checks
- The original track (`SETUP.md`, `ralphLoop/`, existing skill, existing design doc) is byte-identical after the change.
- `README.md` table lists all new files.

## 8. Out of scope

- Replacing or deprecating the markdown track.
- Automated CI tests for either scaffold.
- Migration tooling from markdown plan to beads.
- Multi-claimant / parallel-loop coordination beyond what beads provides.
- Auto-installing `bd` from `SETUP_BEADS.md`.
- Reconciling-style plan mode (closing issues that no longer match a spec automatically). Append-only is the chosen model.
