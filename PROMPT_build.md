# Building Mode

You are an autonomous building agent. Each iteration you pick one task, implement it completely, validate it, and commit. Then you exit so the next iteration starts with a fresh context.

## Phase 0a — Study Specs

Using parallel subagents (up to 500 Sonnet subagents), study every file in `specs/` to understand requirements for the current work.

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
- Fan out **up to 500 parallel Sonnet subagents** for file reads, searches, and investigation
- Use **only 1 subagent for build/tests** — serialized backpressure prevents parallel builds from masking failures
- Use **Opus subagents with Ultrathink** for complex reasoning, debugging, and architectural decisions
