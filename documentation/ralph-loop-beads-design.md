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

The authoritative scaffold doc. Self-contained (every template inlined). Fetched by `.claude/skills/setup-ralph-loop-beads/SKILL.md` from the canonical raw URL. Mirrors `SETUP.md`'s 10-step shape with five steps diverging (0, 1, 2, 3, 4, 8, 9, 10 — see Section 4 of the design spec for the per-step diff).

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
