---
name: setup-ralph-loop
description: This skill should be used when the user asks to "set up ralph loop", "install ralph loop", "scaffold ralph loop", "add ralph loop to this project", "bootstrap huntley's loop", or types /setup-ralph-loop. Fetches SETUP.md from the HuntleysLoop repo and scaffolds a ralphLoop/ directory end-to-end (project analysis, templates, verification, commit).
---

Fetch SETUP.md from https://raw.githubusercontent.com/JuliusGruber/HuntleysLoop/main/SETUP.md using the WebFetch tool. If the fetch fails, surface the error and stop — do not improvise from memory.

Follow every step in that file to scaffold a `ralphLoop/` directory in this repository. SETUP.md includes project analysis (Step 0), all templates, and a verification step — follow it end to end.

Verification: after scaffolding, confirm the target directory exists and the verification step in SETUP.md passes. Then commit the scaffolded files.
