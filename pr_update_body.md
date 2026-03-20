## Phase 2 — PCSS shadows integration

### Summary
Integrated Percentage-Closer Soft Shadows (PCSS) into the composite (lighting) pass.
This PR wires the PCSS algorithm into `shaders/composite.fsh` and adds debugging and test hooks to validate and profile the change in-game.

### Key changes
- `shaders/composite.fsh`
  - Inlined and integrated PCSS stages: blocker search, penumbra estimation, and variable-radius PCF.
  - Added helper functions: `reconstructWorldPosition(...)`, `projectToShadowSpace(...)`.
  - Added `debugMode` uniform (0=off, 1=depth, 2=worldPos, 3=shadowCoord, 4=shadow value) and debug visualization branches.
  - Calls `pcssShadow(...)` in `main()` and applies shadow to final color.
- `shaders/shaders.properties` — minor config/line-ending adjustments.
- `.claude/settings.json` — updated `ANTHROPIC_MODEL` to `qwen/qwen3.5-9b` (agent config; unrelated to shader runtime, included for completeness).

### Minimal testing & validation (run locally)
1. Copy the shader pack folder into Minecraft shaderpacks:

```powershell
$src = 'C:\Users\SillyPewPewPanda\Echelon Nexus Shader Pack'
$dst = Join-Path $env:APPDATA '.minecraft\shaderpacks\Echelon Nexus Shader Pack'
if (Test-Path $dst) { Rename-Item $dst ($dst + '.bak') }
Copy-Item -Recurse -Force $src $dst
```

2. In-game checks
- Start Minecraft 1.21.11 with Iris 1.6.0+ and select the shader pack.
- Visit an outdoor scene with direct sun to inspect shadows.
- Visual expectations:
  - Soft penumbra edges around occluders.
  - No shader compilation errors or black screens.
- Debug visualizations: temporarily set `debugMode` to `4` (grayscale shadow intensity) by editing `composite.fsh` for quick verification, copy the pack, and reload.

3. Performance profiling (baseline vs PCSS):
- Baseline (PCSS off): temporarily disable PCSS by setting `float shadow = 1.0;` in `main()`. Record average frame time (F3) across ~30 frames.
- PCSS (on): restore PCSS call, record average frame time across ~30 frames.
- PCSS overhead = avg_ms_with_pcss - avg_ms_baseline. Target: < 2.0 ms on RTX 3060 (HIGH profile).

### Tuning suggestions (if overhead > 2ms)
- Reduce blocker search sampleCount: 16 -> 8.
- Reduce PCF maximum samples: 32 -> 16.
- Reduce `searchRadius` from 3.0 -> 2.0 and/or reduce `lightSize`.

### Important constraints & notes
- Samplers must only be declared in fragment shaders (`.fsh`).
- Declare varyings at global scope in both `.vsh` and `.fsh`.
- Loops must use constant upper bounds to avoid driver timeouts (e.g., `for (int i = 0; i < 32; i++)`).
- Shadow maps must be sampled in `composite.fsh` only (Iris lifecycle constraints).
- Use `precision highp float;` for depth/position math.

### Next steps
- In-game testing and profiling (I can iterate on tuning based on measurements).
- Optionally, enable a `shaders.properties` flag to control `debugMode` without editing the shader directly.

---

_If you want a different PR body layout or additional file links, tell me and I will update it._
