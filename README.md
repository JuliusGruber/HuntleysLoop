# HuntleysLoop

A template repo for setting up the **Ralph Loop** — an autonomous coding loop powered by Claude CLI.

The Ralph Loop is a bash `while` loop that repeatedly feeds a prompt to `claude -p` in headless mode. Each iteration picks one task, implements it, validates it, commits, and exits with a fresh context window. `IMPLEMENTATION_PLAN.md` on disk is the shared state between iterations.

## Usage

Point Claude at this repo and tell it to follow the setup instructions:

> Set up a Ralph Loop in my project following https://github.com/JuliusGruber/HuntleysLoop

Claude reads `CLAUDE.md`, then follows `SETUP.md` step by step — analyzing your project, scaffolding a `ralphLoop/` directory, and filling in your actual build/test commands.

### As a Claude Code skill

Copy `skills/setup-ralph-loop.md` into your target project:

```bash
mkdir -p .claude/commands
cp skills/setup-ralph-loop.md .claude/commands/setup-ralph-loop.md
```

Then run `/setup-ralph-loop` in Claude Code to scaffold the Ralph Loop.

## What's in this repo

| File | Purpose |
|---|---|
| `CLAUDE.md` | Skill entry point — tells Claude to follow `SETUP.md` |
| `SETUP.md` | Machine-readable setup instructions with all template files inline |
| `skills/setup-ralph-loop.md` | Claude Code skill — copy to your project to enable `/setup-ralph-loop` |
| `ralphLoop/` | Working reference example of the loop files (prompts, loop script, AGENTS.md) |
| `documentation/ralph-loop-design.md` | Design reference — rationale, decisions, prompt engineering patterns |

## How the loop works

1. **Edit `ralphLoop/JTBD.md`** — describe what you want built
2. **`bash ralphLoop/loop.sh specs`** — break the JTBD into behavioral specs
3. **`bash ralphLoop/loop.sh plan`** — study specs + code, produce a prioritized task list
4. **`bash ralphLoop/loop.sh build`** — pick one task per iteration, implement, validate, commit

Each mode uses its own prompt file (`PROMPT_specs.md`, `PROMPT_plan.md`, `PROMPT_build.md`). The loop pushes to remote after each iteration. Override the model with `RALPH_MODEL=sonnet bash ralphLoop/loop.sh build`.

## Requirements

- Claude CLI installed and authenticated
- Git repository
- Run in a sandbox (Docker, E2B, Modal, Fly Sprites, Daytona) — the loop has full permissions
