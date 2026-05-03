# HuntleysLoop

Paste this into any Claude Code conversation to scaffold an autonomous Ralph Loop in your project:

> Fetch https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP.md and follow every step to scaffold a Ralph Loop in this project.

Claude fetches `SETUP.md`, analyzes your project, scaffolds a `ralphLoop/` directory, and fills in your actual build/test/lint commands. One message, no files to copy.

**Beads variant** (if you want a `bd`-backed issue graph instead of a markdown plan; requires the [`bd` CLI](https://github.com/steveyegge/beads) installed):

> Fetch https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md and follow every step to scaffold a beads-driven Ralph Loop in this project.

This scaffolds a `ralphLoopBeads/` directory and runs `bd init`. The two tracks coexist — pick whichever fits your workflow.

## What happens

`SETUP.md` is self-contained — all templates inline, 10 steps, verification at the end. Claude will:

1. Detect your language, framework, build commands, and conventions (Step 0)
2. Create `ralphLoop/` with loop script, prompt files, and a customized `AGENTS.md`
3. Verify everything is correct before finishing

## How the loop works

After setup, you drive the loop:

1. **Edit `ralphLoop/JTBD.md`** — describe what you want built
2. **`bash ralphLoop/loop.sh specs 2`** — break the JTBD into behavioral specs
3. **`bash ralphLoop/loop.sh plan 2`** — produce a prioritized implementation plan
4. **`bash ralphLoop/loop.sh build`** — autonomously implement until done

Each iteration picks one task, implements it, validates (build/test/lint), commits, and exits with a fresh context. `IMPLEMENTATION_PLAN.md` on disk is the shared state between iterations. Override the model with `RALPH_MODEL=sonnet bash ralphLoop/loop.sh build`.

## Alternative: as a skill

If you prefer a reusable skill, install it into your project:

```bash
mkdir -p .claude/skills/setup-ralph-loop
curl -o .claude/skills/setup-ralph-loop/SKILL.md https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/.claude/skills/setup-ralph-loop/SKILL.md
```

Claude will auto-discover it; trigger it by saying "set up ralph loop" or `/setup-ralph-loop`. The beads variant is at `.claude/skills/setup-ralph-loop-beads/SKILL.md`.

## What's in this repo

This repo ships two parallel scaffold tracks — the markdown track (`SETUP.md` → `ralphLoop/` with `IMPLEMENTATION_PLAN.md`) and the beads track (`SETUP_BEADS.md` → `ralphLoopBeads/` with a `bd` issue graph). Pick whichever fits your workflow; they coexist.

| File | Purpose |
|---|---|
| `SETUP.md` | Self-contained setup instructions with all templates inline |
| `.claude/skills/setup-ralph-loop/SKILL.md` | Claude Code skill — copy into your project's `.claude/skills/` to enable `/setup-ralph-loop` |
| `ralphLoop/` | Reference example (not used during setup — templates come from `SETUP.md`) |
| `documentation/ralph-loop-design.md` | Design rationale and prompt engineering patterns (markdown track) |
| `SETUP_BEADS.md` | Self-contained setup instructions for the beads track, with all templates inline |
| `.claude/skills/setup-ralph-loop-beads/SKILL.md` | Claude Code skill — copy into your project's `.claude/skills/` to enable `/setup-ralph-loop-beads` |
| `ralphLoopBeads/` | Reference example for the beads track (no real `.beads/` shipped — created by `bd init` at scaffold time) |
| `documentation/ralph-loop-beads-design.md` | Design rationale for the beads track |

## Requirements

- Claude CLI installed and authenticated
- Git repository
- Run the loop in a sandbox (Docker, E2B, Modal, Daytona) — it uses `--dangerously-skip-permissions`
