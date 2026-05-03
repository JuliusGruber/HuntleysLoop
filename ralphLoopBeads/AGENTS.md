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
