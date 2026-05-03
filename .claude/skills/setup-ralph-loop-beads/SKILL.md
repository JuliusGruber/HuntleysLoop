---
name: setup-ralph-loop-beads
description: This skill should be used when the user asks to "set up beads ralph loop", "install ralph loop with beads", "scaffold beads-driven loop", "add ralph-loop-beads", "bootstrap beads loop", or types /setup-ralph-loop-beads. Fetches SETUP_BEADS.md from the HuntleysLoop repo and scaffolds a ralphLoopBeads/ directory. Requires the bd CLI; halts at Step 0 with install instructions if missing.
---

Before fetching, verify the `bd` CLI is installed by running `bd --version`. If it fails, point the user at https://github.com/steveyegge/beads for install instructions and stop.

Fetch SETUP_BEADS.md from https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP_BEADS.md using the WebFetch tool. If the fetch fails, surface the error and stop — do not improvise from memory.

Follow every step in that file to scaffold a `ralphLoopBeads/` directory in this repository. SETUP_BEADS.md includes a `bd`-installed pre-flight check (Step 0), project analysis, all templates, and a verification step — follow it end to end.

Verification: after scaffolding, confirm the target directory and `.beads/` exist and the verification step in SETUP_BEADS.md passes. Then commit the scaffolded files (including `.beads/`).
