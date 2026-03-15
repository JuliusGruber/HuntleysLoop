# Running the Ralph Loop

After scaffolding the `ralphLoop/` directory (via the setup skill or by pasting the SETUP.md prompt), follow this guide to start and operate the loop.

---

## Prerequisites

- **Claude CLI** installed and authenticated (`claude --version` to verify)
- **Git repository** initialized with at least one commit
- **Sandbox environment** (Docker, E2B, Modal, Daytona, etc.) — the loop runs with `--dangerously-skip-permissions`, so never run it on an uncontained machine

## Quick Start

```bash
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
```

## Loop Modes

The loop script (`ralphLoop/loop.sh`) accepts two arguments:

```
bash ralphLoop/loop.sh <mode> [max_iterations]
```

| Mode | What it does | Typical iterations |
|---|---|---|
| `specs` | Reads `JTBD.md` and produces behavioral spec files in `ralphLoop/specs/` | 1-2 |
| `plan` | Reads specs and source code, writes a prioritized task list to `IMPLEMENTATION_PLAN.md` | 1-2 |
| `build` | Picks the next task from the plan, implements it, validates, commits, and exits so the next iteration starts fresh | Until all tasks are done |

If `max_iterations` is omitted or `0`, the loop runs indefinitely (useful for `build` mode).

## Choosing a Model

The loop defaults to Opus. Override with the `RALPH_MODEL` environment variable:

```bash
# Use Sonnet for faster, cheaper iterations
RALPH_MODEL=sonnet bash ralphLoop/loop.sh build

# Use Opus (default) for maximum capability
RALPH_MODEL=opus bash ralphLoop/loop.sh build
```

## The Workflow in Detail

### 1. Write Your JTBD

Edit `ralphLoop/JTBD.md` to describe **what** you want built. Focus on outcomes, not implementation details.

Good: "Users can sign up with email, log in, reset their password, and view their profile."
Bad: "Create a React component using NextAuth with Prisma adapter..."

### 2. Run Specs Mode

```bash
bash ralphLoop/loop.sh specs 2
```

The agent reads your JTBD and breaks it into one spec file per topic of concern in `ralphLoop/specs/`. Each spec contains a summary, context, acceptance criteria, edge cases, and out-of-scope notes.

Review the generated specs. This is your best leverage point — fixing a spec now is much cheaper than fixing code later.

### 3. Run Planning Mode

```bash
bash ralphLoop/loop.sh plan 2
```

The agent studies the specs and your existing source code, performs gap analysis, and writes a prioritized task list to `ralphLoop/IMPLEMENTATION_PLAN.md`. Tasks are ordered by dependencies, then foundational work, then core functionality.

Review the plan. Reorder or remove tasks if needed — the build loop trusts this file.

### 4. Run Build Mode

```bash
bash ralphLoop/loop.sh build
```

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

```bash
# See what's been done and what's next
cat ralphLoop/IMPLEMENTATION_PLAN.md

# See commit history
git log --oneline

# See tagged builds
git tag
```

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
