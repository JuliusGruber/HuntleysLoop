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
