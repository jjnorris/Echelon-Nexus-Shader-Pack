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

External References — Always Check
---------------------------------
- Photon/Complementary Reimagined shader repos: compare shadow/PCF/PCSS approaches and sample counts.
- Iris shaderpack documentation and compatibility notes (Iris versions and shader API changes).
- Minecraft shaderpack constraints for 1.21.11 (texture limits, varying rules, semantics).
- GLSL reference /OpenGL specs for targeted `#version` (130 vs 330).
- GPU vendor docs for precision/format caveats (NVIDIA/AMD/Intel driver notes).

Mandatory Pre-edit Checklist
----------------------------
Before changing shaders or adding presets, verify all items below and record the results in the PR description:

- Target GLSL version: confirm whether change targets `#version 130` (compat) or a newer `#version 330` preset. If adding `gl330` codepath, provide a fallback for older drivers.
- Samplers: ensure samplers are declared only in fragment shaders (`.fsh`).
- Varyings: declare varyings at global scope and match types/names between `.vsh` and `.fsh`.
- Loop bounds: loops must use constant upper bounds; avoid dynamic loop termination conditions.
- Texture sample budget: ensure each pass uses <= 32 texture samples. Document sample counts in the PR.
- Shadow sampling: shadow textures must be sampled in `composite.fsh` only; if caching shadow results, write to a color target in composite pass.
- Precision: use `highp` for depth/position math in `#version 130`; gl330 presets may omit precision qualifiers.
- Depth convention: verify shadow-map depth convention (some drivers/engines invert stored depth). Use debug modes (7/9) to confirm and set `shadowDepthInvert` accordingly.
- BOM/Encoding: save GLSL files as UTF-8 without BOM. Re-run a shader reload to catch preprocessing issues.
- Automated tests: run `scripts/select-shader-preset.ps1` and `scripts/build-pack-variant.ps1` locally to generate a pack variant and validate the build.

Verification Steps (required before merge)
----------------------------------------
1. Ensure shader compiles/loads with Iris + Minecraft 1.21.11 on a representative GPU or via CI image if available.
2. Run minimal validation: install the pack, reload shaders (F3+T), then collect `%APPDATA%\\.minecraft\\logs\\latest.log` and confirm no shader compilation errors.
3. Produce performance measurements (30-frame mean) for Baseline and PCSS on an RTX 3060 (HIGH profile) and include numbers in PR.
4. Include screenshots for `debugMode=4` (PCSS value) and any diagnostic modes used to diagnose depth conventions.

When to Add a New Pack Variant
--------------------------------
- Add a new preset or pack variant when you need shader features that are not portable to `#version 130` (e.g., modern GLSL constructs), or when a dramatically different sample budget is required for low-end GPUs.
- For each variant add: a `shaders/presets/<preset>.fsh`, an entry in `README.md` mapping hardware  preset, and update `scripts/select-shader-preset.ps1`.

Release & Packaging
-------------------
- Use `scripts/build-pack-variant.ps1 -preset <name>` to create a zipped release for a given preset.
- Tag releases with `preset-<name>` and include measured frame times and the test scene used in the release notes.

Agent Behavior Notes (stronger)
-------------------------------
- ALWAYS run repo-wide text search for `sampler` / `precision` / `#version` before edits and follow the `Mandatory Pre-edit Checklist`.
- ALWAYS consult the listed external references for shadow/PCF/PCSS best practices before changing PCSS code.
- When adding a `gl330` preset, add clear fallback behavior and document risks in the PR. Do not remove `#version 130` compatibility without explicit approval.

Keep this file concise — link to deeper docs rather than duplicating them.
