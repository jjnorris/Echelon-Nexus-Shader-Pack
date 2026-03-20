---
name: "Echelon Nexus — Workspace Instructions"
description: |
  Agent workspace instructions for the Echelon Nexus Shader Pack repository.  
  These instructions give contributors and automation a concise, project-specific
  policy for editing, testing, and validating shaders, and list the most
  important constraints and quick commands needed to run local validation.
applyTo:
  - "shaders/**"
  - "shaders/program/**"
  - "shaders/*.fsh"
  - "shaders/*.vsh"
  - "shaders.properties"
---

Purpose
-------
Provide a compact, actionable reference for agents and contributors working on
the Echelon Nexus Shader Pack. Follow these rules to avoid common shader errors
and to make changes small, testable, and reversible.

Quick Start
-----------
- Copy the pack into your Minecraft `shaderpacks` folder (see "Minimal validation").
- Use small commits and a branch name starting with `claude/` for feature work.
- Open a PR against the default branch: `claude/echelon-nexus-shader-LVvG4`.

Key Files
---------
- Phase 2 integration: `shaders/composite.fsh` ([file](shaders/composite.fsh))
- PCSS algorithm: `shaders/program/pcss.glsl` ([file](shaders/program/pcss.glsl))
- Pack options: `shaders/shaders.properties` ([file](shaders/shaders.properties))
- Reference snippets: `CODE_SNIPPETS.md` ([file](CODE_SNIPPETS.md))
- Phase guide: `PHASE_2_IMPLEMENTATION_GUIDE.md` ([file](PHASE_2_IMPLEMENTATION_GUIDE.md))

Critical Conventions (Read Before Editing)
-----------------------------------------
- Samplers ONLY in fragment shaders (`.fsh`). Do NOT declare samplers in `.vsh` files.
- Declare varyings at GLOBAL scope in both `.vsh` and `.fsh` and keep names/types matched.
- Max texture samples per pass: 32. Keep sampler counts under GPU limits.
- Loops must use constant upper bounds. Use `for (int i = 0; i < 32; i++)` not dynamic loop bounds.
- Shadow textures MUST be sampled in `composite.fsh` only. If you need cached shadow data later,
  store it in a color target in the composite pass.
- Use `precision highp float;` for depth/position math. Colors may use `mediump`.
- Always clamp shadow coords and treat out-of-bounds as fully lit.

Testing & Minimal Validation
----------------------------
1. Copy pack into Minecraft shaderpacks (PowerShell):

```powershell
$src = 'C:\Users\SillyPewPewPanda\Echelon Nexus Shader Pack'
$dst = Join-Path $env:APPDATA '.minecraft\shaderpacks\Echelon Nexus Shader Pack'
if (Test-Path $dst) { Rename-Item $dst ($dst + '.bak') }
Copy-Item -Recurse -Force $src $dst
```

2. In-game checks (Minecraft 1.21.11 + Iris 1.6.0+):
- Load the shader pack and open a sunny outdoor scene.
- Verify no compilation errors or black screens on shader load.
- Visual check: soft penumbra edges, no flicker.

3. Profiling (baseline vs PCSS):
- Baseline: temporarily replace PCSS result with `float shadow = 1.0;`, reload, record average ms (F3) for ~30 frames.
- PCSS: restore `pcssShadow(...)`, reload, record average ms for ~30 frames.
- PCSS overhead target: < 2.0 ms on RTX 3060 (HIGH profile).

Dev Helper: Toggle debug visualization
-------------------------------------
Use the helper script `scripts/toggle-debug-mode.ps1` to set `debugMode` in
`shaders/composite.fsh` for quick visual checks (0=off,1=depth,2=worldPos,3=shadowCoord,4=shadow value).

Tuning Guidance
---------------
If PCSS exceeds the performance budget:
- Reduce blocker search samples: 16 -> 8
- Reduce PCF max samples: 32 -> 16
- Reduce `searchRadius` from 3.0 -> 2.0

Agent Behavior Notes
--------------------
- Use read-only exploration before editing. Prefer small, focused commits.
- When in doubt, add debug visualizations rather than compressing logic.
- Keep large loops statically bounded and avoid dynamic branching inside high-frequency loops.

PR / Branching
--------------
- Branch name format: `claude/<short-description>-<id>`
- PR base: `claude/echelon-nexus-shader-LVvG4` (default branch)
- Include measured frame times and the scene used for profiling in PR description.

Where to ask for help
---------------------
- Repo owner / maintainer: `jjnorris` (PR: https://github.com/jjnorris/Echelon-Nexus-Shader-Pack/pull/1)

Keep this file concise — link to deeper docs rather than duplicating them.
