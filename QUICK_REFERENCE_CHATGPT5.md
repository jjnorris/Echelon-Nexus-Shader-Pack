# ⚡ QUICK REFERENCE CARD FOR CHATGPT 5 MINI
## Everyday Development Cheat Sheet

---

## 🚀 START YOUR DAY

```bash
# 1. Update your branch
cd /home/user/Echelon-Nexus-Shader-Pack
git pull origin claude/fix-shader-sampler-deps-Smgdj

# 2. Check current status
git status
git log --oneline -5

# 3. Launch Minecraft test world
# (With Iris 1.6.0+ loaded)
```

---

## 🔧 COMMON TASKS

### Task: Fix a Shader Compilation Error
```
1. Check Minecraft debug log: ~/.minecraft/logs/latest.log
2. Find the error message (usually shows file and line number)
3. Open that file in shaders/program/
4. Check for:
   ✓ Missing semicolons
   ✓ Undefined variables
   ✓ Samplers in .vsh files (❌ wrong, move to .fsh)
   ✓ Varying declaration mismatch
5. Fix and reload (in-game Shift+R in Iris)
6. Commit: git commit -m "fix: [what was wrong]"
```

### Task: Reduce Frame Time
```
1. Profile in-game: F3 debug, note "Rendering" time
2. If >20ms, something is wrong
3. Most likely causes:
   ✓ Too many texture samples (>32 per pass)
   ✓ Loop count too high (>64 iterations)
   ✓ Expensive operations in fragment shader
4. Fix:
   ✓ Reduce sample count
   ✓ Cap loop: min(sampleCount, 32)
   ✓ Replace sqrt() with squared values
   ✓ Replace pow() with multiplication
5. Test and commit
```

### Task: Test Shadows
```
1. Create world with varied terrain
2. Note sun position (use F3 coordinates)
3. Look for:
   ✓ Shadows on ground
   ✓ Soft shadow edges (not sharp/aliased)
   ✓ Shadow direction matches sun
   ✓ No black screen
   ✓ No flickering
4. If issues, check:
   ✓ Shadow coordinates [0,1] range
   ✓ Shadow depth comparison logic
   ✓ PCSS parameters (lightSize=0.5, searchRadius=3.0)
```

### Task: Add a New Feature
```
1. Read relevant section in PHASE_2_IMPLEMENTATION_GUIDE.md
2. Create/edit file in shaders/program/
3. Test after every 5-10 lines
4. Keep changes small (one feature per commit)
5. Commit: git commit -m "feat: [what was added]"
6. Push: git push -u origin claude/fix-shader-sampler-deps-Smgdj
```

### Task: Document a Mistake
```
1. Write down:
   - What happened (the bug)
   - Why it happened (root cause)
   - How you fixed it (solution)
   - Code that prevents it (pattern)
2. Add to HANDOFF_TO_CHATGPT5_COMPREHENSIVE.md
3. Create commit: git commit -m "docs: Log mistake #N - [title]"
```

---

## 📋 CRITICAL CODE PATTERNS

### Depth Reconstruction (Phase 2)
```glsl
// In composite.fsh
vec3 reconstructWorldPosition(vec2 uv, float depth) {
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth * 2.0 - 1.0);
    vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
    viewPos /= viewPos.w;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    return worldPos.xyz;
}
```

### Shadow Space Transformation
```glsl
vec2 projectToShadowSpace(vec3 worldPos) {
    vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    shadowPos /= shadowPos.w;
    return shadowPos.xy * 0.5 + 0.5;  // [-1,1] to [0,1]
}
```

### PCSS Call Pattern
```glsl
void main() {
    vec4 baseColor = texture(colortex0, uv);
    float depth = texture(depthtex0, uv).r;

    if (depth > 0.9999) {  // Skip sky
        fragColor = baseColor;
        return;
    }

    vec3 worldPos = reconstructWorldPosition(uv, depth);
    vec2 shadowCoord = projectToShadowSpace(worldPos);
    float shadowDepth = ...;  // Calculate shadow depth

    // Call PCSS (from pcss.glsl)
    float shadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth, 0.5, 3.0);

    vec3 shadowed = baseColor.rgb * (0.5 + shadow * 0.5);
    fragColor = vec4(shadowed, baseColor.a);
}
```

### Safe Texture Sampling
```glsl
// Always clamp shadow coordinates
vec2 shadowCoord = clamp(projectToShadowSpace(worldPos), 0.0, 1.0);

// Check bounds before sampling
if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
    shadowCoord.y < 0.0 || shadowCoord.y > 1.0) {
    // Out of shadow map, fully lit
    shadow = 1.0;
} else {
    shadow = pcssShadow(...);
}
```

### Variable Declaration (Fragment Shader)
```glsl
#version 130

// ✅ CORRECT - Samplers ONLY in fragment shader
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D shadowtex0;
uniform sampler2D depthtex0;

// Varyings (global scope)
varying vec3 vNormal;
varying vec2 vUV;
varying vec3 vWorldPos;

// Matrices (from Iris)
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

void main() {
    // Your code here
}
```

### Precision Declaration
```glsl
// At top of fragment shader
precision highp float;

// For depth-critical code
highp float depth = texture(depthtex0, uv).r;
highp vec3 worldPos = reconstructWorldPosition(uv, depth);

// Color can use mediump
mediump vec3 color = texture(colortex0, uv).rgb;
```

---

## ⚠️ THINGS THAT WILL BREAK YOUR SHADER

### ❌ DON'T DO THESE

```glsl
// 1. Samplers in vertex shader
// vertex.vsh - WRONG!
uniform sampler2D myTexture;  // ❌ COMPILATION ERROR

// 2. Wrong include path
#include "/lib/myfile.glsl"  // ❌ FILE NOT FOUND (use /program/)

// 3. Varyings in function scope
void main() {
    varying float myVar;  // ❌ LINKING ERROR
}

// 4. Using shadowtex in composite1+
// composite1.fsh
vec4 shadow = texture(shadowtex0, uv);  // ❌ MIGHT NOT EXIST

// 5. Dynamic loop count
for (int i = 0; i < sampleCount; i++) {  // ❌ TIMEOUT
    // Loop count unknown at compile time
}

// 6. Too many texture samples
// 12+ unique samplers in one pass  // ❌ EXCEEDS LIMIT

// 7. Expensive function in tight loop
for (int i = 0; i < 64; i++) {
    float x = pow(value, 2.5);  // ❌ VERY SLOW
    // Better: float x = value * value  // ✅ FAST
}

// 8. Missing gamma correction
fragColor = myColor;  // ❌ WRONG COLOR SPACE

// 9. Uninitialized variable
float shadow;
if (condition) shadow = 0.5;
else shadow = 1.0;
vec3 lit = color * (shadow);  // ✓ OK in this case

// 10. Using depth directly
float brightness = texture(depthtex0, uv).r;  // Usually wrong
// Depth is usually 0.999+ for distant objects
```

---

## 🧪 TESTING CHECKLIST

Before committing, verify:

```
Visual Quality:
  ☐ No black screen
  ☐ Shadows visible
  ☐ Correct shadow direction
  ☐ No obvious glitches
  ☐ Colors look reasonable
  ☐ No flickering

Performance:
  ☐ Frame time < 20ms (ideally < 16.67ms)
  ☐ No stuttering
  ☐ No frame rate drops

Functionality:
  ☐ Shader compiles without errors
  ☐ Reloads with Shift+R in Iris
  ☐ Works at multiple times of day
  ☐ Works on varied terrain

Compatibility:
  ☐ Tested on HIGH profile (if changed)
  ☐ No crashes
  ☐ All gbuffers programs defined
```

---

## 🐛 DEBUG TECHNIQUES

### Visualize Intermediate Values
```glsl
// Output depth as color (white = far, black = near)
fragColor = vec4(vec3(depth), 1.0);

// Output world position (clipped to [0,1])
vec3 worldPosNormalized = worldPos / 256.0;  // Adjust scale
fragColor = vec4(worldPosNormalized, 1.0);

// Output shadow value (white = lit, black = shadow)
fragColor = vec4(vec3(shadow), 1.0);

// Output normal as color
fragColor = vec4(normal * 0.5 + 0.5, 1.0);  // Map [-1,1] to [0,1]
```

### Use Minecraft Debug Output
```glsl
// In composite.fsh, if something is very wrong:
if (any(isnan(fragColor))) {
    // NaN detected - something computed wrong
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);  // Flash red
}
```

### Systematic Testing
```
1. Simplify: Remove complex code, test basic version
2. Isolate: Test one feature at a time
3. Instrument: Add debug color output
4. Profile: Measure where time is spent
5. Optimize: Fix the bottleneck
```

---

## 📊 PERFORMANCE BUDGET ALLOCATION

```
60 FPS = 16.67ms per frame

Phase 1 COMPLETE:
  Shadow rendering:    1-2 ms ✅
  Composite (Cook-T):  2-3 ms ✅
  Final tonemapping:   0.5-1 ms ✅
  Subtotal:            3.5-6 ms ✅

Phase 2 IN PROGRESS (TARGET):
  PCSS shadows:        < 2 ms (blocker + PCF only)
  Subtotal Phase 2:    < 2 ms ✅

Remaining Budget:     ~10-12 ms
  For Phases 3-7, driver overhead, CPU overhead

IF YOUR CODE EXCEEDS 2ms FOR PHASE 2:
  1. Reduce blocker search to 8 samples (from 16)
  2. Reduce PCF samples to 16 max (from 32)
  3. Reduce search radius to 2.0 (from 3.0)
  4. Skip cascade blending (use fixed cascade)
  5. Profile to find the bottleneck
```

---

## 📞 IF YOU GET STUCK

### Problem: "Shader won't compile"
```
Check: ~/.minecraft/logs/latest.log
Look for: "Error parsing" or "Compilation failed"
Common causes:
  1. Sampler in .vsh file ❌
  2. Missing semicolon ❌
  3. Undefined variable ❌
  4. Wrong include path ❌
Solution: Search this doc or HANDOFF_TO_CHATGPT5_COMPREHENSIVE.md
```

### Problem: "Black screen or no shaders loading"
```
Verify:
  1. Iris is installed and enabled
  2. shaders.properties is valid
  3. pack.mcmeta exists
  4. Minecraft version is 1.21.11
Solution: Check shaders.properties syntax or compare to backup
```

### Problem: "Shadows are sharp or wrong color"
```
Adjust parameters in composite.fsh:
  - lightSize: Increase for softer shadows (0.3-1.0)
  - searchRadius: Increase for larger penumbra (2.0-4.0)
Solution: Test different values, measure quality vs. perf
```

### Problem: "Performance tanked after my changes"
```
1. Measure frame time before/after
2. Profile which pass is slow
3. Check for:
   - Loop count too high
   - Texture sample count > 32
   - Expensive operations (pow, sqrt, sin)
   - Dependent texture reads
Solution: See "Reduce Frame Time" section above
```

### Problem: "I don't understand how this works"
```
Resources:
  1. PHASE_2_IMPLEMENTATION_GUIDE.md - Step by step
  2. MINECRAFT_1.21.11_CONSTRAINTS.md - Capabilities
  3. CODE_SNIPPETS.md - Working examples
  4. Research papers - Math foundation
  5. Comments in phase 1 composite.fsh - Reference code
```

---

## 📝 BEFORE YOU COMMIT

Checklist:
```
☐ Code is tested in Minecraft
☐ No shader compilation errors
☐ Frame time acceptable (< 20ms)
☐ Visual quality is good
☐ Changes are focused (one feature per commit)
☐ Commit message is clear
☐ Branch is up to date (git pull first)

Then:
  git add <files>
  git commit -m "type: message"
  git push -u origin claude/fix-shader-sampler-deps-Smgdj

Never:
  ✗ Force push (--force)
  ✗ Rewrite history (--amend on pushed commits)
  ✗ Large vague commits ("fix: stuff")
  ✗ Commit broken code
```

---

## 🎯 YOUR IMMEDIATE TASK

**PHASE 2 - PCSS IMPLEMENTATION CHECKLIST**

Week 1 Goals:
```
☐ Implement depth reconstruction (composite.fsh)
☐ Implement shadow space transformation
☐ Integrate PCSS algorithm call
☐ Test shadows appear in-game
☐ Verify soft edges on shadows
☐ Measure frame time overhead
☐ Commit: feat: Phase 2 - PCSS integration complete
```

Success = Soft shadows visible with < 2ms overhead

---

## 📖 DOCUMENT MAP

| Document | Purpose | When to Read |
|----------|---------|--------------|
| HANDOFF_TO_CHATGPT5_COMPREHENSIVE.md | Complete context and mistakes | Start here, reference anytime |
| PROJECT_VISION.md | Goals and roadmap | Understand the big picture |
| MINECRAFT_1.21.11_CONSTRAINTS.md | Hard limits | Before designing anything |
| PHASE_2_IMPLEMENTATION_GUIDE.md | Step-by-step PCSS | Your main guide right now |
| CODE_SNIPPETS.md | Working code examples | When writing new code |
| QUICK_REFERENCE_CHATGPT5.md | This document | Daily reference while coding |

---

**Keep this tab open while you work. Refer to it constantly.**

**Good luck! You've got this. 🚀**
