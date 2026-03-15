# HuntleysLoop

A template repo for setting up the **Ralph Loop** — an autonomous coding loop powered by Claude CLI.

The Ralph Loop is a bash `while` loop that repeatedly feeds a prompt to `claude -p` in headless mode. Each iteration picks one task, implements it, validates it, commits, and exits with a fresh context window. `IMPLEMENTATION_PLAN.md` on disk is the shared state between iterations.

## Usage

Point Claude at this repo and tell it to follow the setup instructions:

> Set up a Ralph Loop in my project following https://github.com/JuliusGruber/HuntleysLoop

Claude reads `SETUP.md`, which contains all template files inline, and scaffolds a `ralphLoop/` directory in your project.

## What's in this repo

| File | Purpose |
|---|---|
| `SETUP.md` | Machine-readable setup instructions with all template files inline |
| `ralphLoop/` | Working example of the loop files (prompts, loop script, AGENTS.md) |
| `documentation/ralph-loop-design.md` | Design reference — rationale, decisions, prompt engineering patterns |

## How the loop works

1. **`bash ralphLoop/loop.sh specs`** — break a Job to Be Done into behavioral specs
2. **`bash ralphLoop/loop.sh plan`** — study specs + code, produce a prioritized task list
3. **`bash ralphLoop/loop.sh build`** — pick one task per iteration, implement, validate, commit

Each mode uses its own prompt file (`PROMPT_specs.md`, `PROMPT_plan.md`, `PROMPT_build.md`). The loop pushes to remote after each iteration.

## Requirements

- Claude CLI installed and authenticated
- Git repository
- Run in a sandbox (Docker, E2B, Modal, Fly Sprites, Daytona) — the loop has full permissions
