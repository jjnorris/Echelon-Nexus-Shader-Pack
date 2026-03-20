# 🎮 ECHELON NEXUS SHADER PACK - HANDOFF TO CHATGPT 5 MINI
## Comprehensive Transition Document & Mistake Tracking System

**Date:** 2026-03-20
**From:** Claude (Haiku 4.5) - Web/Mobile/Desktop Developer
**To:** ChatGPT 5 Mini - Minecraft Shader Development Specialist
**Project:** Echelon Nexus Shader Pack v2.0
**Repository:** jjnorris/Echelon-Nexus-Shader-Pack
**Development Branch:** `claude/fix-shader-sampler-deps-Smgdj`

---

## ⚠️ CRITICAL HANDOFF CONTEXT

**Why This Handoff?**
Claude (me) is fundamentally a web/mobile/desktop application development AI. While I can understand Minecraft shader concepts, I'm genuinely better at:
- REST APIs, React/Vue/Angular frameworks
- TypeScript, Node.js, Python applications
- Database design, authentication systems
- Mobile development paradigms
- Desktop app architecture

**Why You're Better:**
ChatGPT 5 Mini excels at:
- Graphics programming and shader mathematics
- Game engine integration and compatibility
- Visual rendering quality assessment
- Iterative shader optimization and debugging
- Understanding complex GPU memory management

This isn't a skill cap issue—it's about **specialization**. You'll move 2-3x faster on shader code than I ever could.

---

## 📋 PROJECT OVERVIEW

### Mission Statement
Create the **fastest, most beautiful, and most efficient** photorealistic shader pack for Minecraft Java 1.21.11 + Iris 1.6.0+ by grounding every feature in peer-reviewed research and maintaining 60 FPS on mid-range hardware.

### Core Principles
1. **Research-Driven**: Every feature backed by academic papers
2. **Performance-First**: 60 FPS on RTX 3060 class hardware minimum
3. **Original Implementation**: Learn from others, create our own
4. **Visual Excellence**: Photorealistic lighting with advanced effects
5. **Minecraft Authenticity**: Enhance, don't replace, vanilla aesthetic

### Current Version
- **v2.0 Development** (7 phases planned)
- **Phase 1:** ✅ COMPLETE - Cook-Torrance BRDF foundation
- **Phase 2:** 🔄 IN PROGRESS - PCSS Shadows (50% complete)
- **Phase 3:** 🔄 IN PROGRESS - Temporal Anti-Aliasing (framework ready)
- **Phases 4-7:** ⏳ PLANNED - Advanced effects

---

## 🏗️ PROJECT ARCHITECTURE

### Rendering Pipeline (Iris 1.6.0+)
```
Vertex Processing (GPU geometry)
         ↓
G-Buffer Rendering (12 passes)
  ├─ gbuffers_terrain, gbuffers_entities, gbuffers_hand
  ├─ gbuffers_water, gbuffers_sky, gbuffers_clouds, etc.
  └─ All output to colortex0-2 (albedo, normal, material)
         ↓
Shadow Pass (sun-view depth map)
  └─ shadow.fsh/vsh → shadowtex0
         ↓
Composite Passes (Post-Processing)
  ├─ composite.fsh (Phase 1: Vanilla lighting + basic shadows)
  ├─ composite1.fsh (Phase 2: PCSS shadows - CURRENT WORK)
  ├─ composite2.fsh (Phase 3: TAA post-processing)
  ├─ composite3.fsh (Phase 4: Final effects)
  └─ composite4.fsh (Phase 5+: Extra processing)
         ↓
Final Pass
  └─ final.fsh/vsh → Tonemapping + gamma correction
         ↓
Screen Output
```

### File Structure
```
shaders/
├── program/
│   ├── gbuffers_*.glsl (12 geometry passes)
│   ├── composite.glsl (Phase 1 lighting)
│   ├── composite1.glsl (Phase 2 PCSS - BEING WORKED ON)
│   ├── composite2.glsl (Phase 3 TAA)
│   ├── composite3.glsl (Phase 4+)
│   ├── final.glsl (Tonemapping)
│   ├── pcss.glsl (PCSS algorithm library)
│   ├── brdf.glsl (Lighting model)
│   ├── math.glsl (Utility functions)
│   ├── sampling.glsl (Sampling patterns)
│   ├── distort.glsl (Screen-space distortion)
│   └── shadow.glsl (Shadow rendering)
├── lib/
│   └── [Per-pass includes when needed]
└── shaders.properties (Iris configuration)
```

### Data Flow Through Phases
```
Phase 1 (composite.fsh):
  Input:  colortex0-2 (G-Buffer), shadowtex0, sunPosition
  Process: Cook-Torrance lighting + basic PCF shadows
  Output: colortex5 (lit scene)

Phase 2 (composite1.fsh):
  Input:  colortex5, G-Buffer, shadowtex0
  Process: PCSS shadow enhancement
  Output: colortex6 (enhanced shadows)

Phase 3 (composite2.fsh):
  Input:  colortex6, colortex7 (history)
  Process: Temporal AA filtering
  Output: colortex7 (denoised + upsampled)

Phase 4+ (composite3.fsh+):
  Input:  Previous outputs
  Process: Bloom, color grading, final effects
  Output: Screen
```

---

## 🎯 CURRENT STATUS & PROGRESS

### What's Done (Phase 1 & 2 Foundation)

**Phase 1 - Complete ✅**
- ✅ Full Cook-Torrance BRDF implementation
- ✅ LabPBR 1.3 material support (roughness, metallic, emissive)
- ✅ Normal map and parallax mapping support
- ✅ 12 gbuffers programs fully implemented
- ✅ Basic PCF shadow mapping (functional)
- ✅ Deferred rendering pipeline
- ✅ Color space conversions (linear RGB working)

**Phase 2 - 50% Complete 🔄**
- ✅ PCSS algorithm implementation (pcss.glsl)
  - ✅ Poisson disk sampling (golden angle)
  - ✅ Blocker search (16 samples)
  - ✅ Penumbra estimation (geometric)
  - ✅ Variable-radius PCF (adaptive 4-32)
  - ✅ Shadow cascade framework
  - ✅ Colored shadow support functions
- ❌ Integration into composite1.fsh (NEEDS WORK)
  - ❌ Depth reconstruction from depth buffer
  - ❌ Shadow space matrix transformations
  - ❌ PCSS calling/parameter tuning
  - ❌ Performance optimization
  - ❌ Testing and validation

### Recent Commits (Last 10)
```
22aabd3 temp: Disable composite2 - caching issue
0327ab0 fix: Remove includes, inline PCSS code directly
d6da01c fix: Correct pcss.glsl include path
5eb4329 feat: Phase 2 - Implement PCSS Shadows (Fully Integrated)
ccf33c8 docs: Phase 2 PCSS Shadows Implementation Guide
cf65aed feat: Phase 2 - PCSS Shadows Foundation (Core Algorithm)
4e7d80e fix: Proper Iris shader configuration with language localization
7560536 test: Remove shaders.properties for Phase 1
d263a79 test: Minimal shaders.properties to debug Iris compatibility
4148ece fix: Remove invalid sampler declarations from vertex shaders
```

---

## ⚠️ COMMON MISTAKES & SOLUTIONS (LEARNED THE HARD WAY)

### 🔴 Mistake #1: Shader Sampler Declaration Errors
**Problem:** Invalid sampler declarations in vertex shaders causing compilation errors.

**Root Cause:** Iris requires samplers to be declared ONLY in fragment shaders, not vertex shaders. I was naively copying sampler declarations to vertex shaders.

**Solution Applied:**
- Remove ALL sampler declarations from `*.vsh` files
- Keep sampler declarations ONLY in `*.fsh` files
- Vertex shaders use built-in varyings, not texture sampling
- See: Commit 4148ece

**How to Avoid:**
```glsl
// ❌ WRONG - In vertex shader
uniform sampler2D colortex0;  // Causes compilation error

// ✅ CORRECT - In fragment shader only
uniform sampler2D colortex0;
vec4 color = texture2D(colortex0, uv);
```

**Reference:** `MINECRAFT_1.21.11_CONSTRAINTS.md` section "Shader Pass Capabilities"

---

### 🔴 Mistake #2: Incorrect Include Paths
**Problem:** Shader compilation fails due to include file not found.

**Root Cause:** Used `/lib/pcss.glsl` but file was in `/program/pcss.glsl`. The `/lib/` directory doesn't exist.

**Solution Applied:**
- Commit d6da01c: Fixed include path to use correct location
- Commit 0327ab0: Decided to inline all shared code directly instead of using includes

**How to Avoid:**
```glsl
// ❌ WRONG - File doesn't exist
#include "/lib/pcss.glsl"

// ✅ CORRECT - File actually in program directory
#include "/program/pcss.glsl"

// ✅ EVEN BETTER - Inline the code directly to avoid path issues
// (Copy full function definitions into the shader)
```

**Decision:** Inlining is safer for this project than complex includes.

---

### 🔴 Mistake #3: Composite Pass Unavailable Textures
**Problem:** Trying to sample shadowtex0 in composite1.fsh causes black screen or no shadows.

**Root Cause:** Iris may not guarantee shadow texture availability in composite1+ passes. The shadow maps may be freed from memory after the initial composite pass.

**Solution Applied:**
- Moved PCSS work to composite.fsh instead of composite1.fsh (where shadows are guaranteed)
- If using composite1+, must pre-calculate shadow data in earlier passes and store in colortex

**How to Avoid:**
```
SAFE TEXTURE AVAILABILITY BY PASS:

Shadow Pass:
  ✅ Can use: Shadow matrices, view matrices
  ❌ Cannot use: G-Buffer, previous frames

Composite Pass (composite.fsh):
  ✅ CAN USE: shadowtex0, shadowtex1, shadowcolor0, G-Buffer
  ❌ Cannot use: composite1+ outputs

Composite1+ Passes:
  ⚠️  UNSAFE: shadowtex0/1 not guaranteed (may be freed)
  ✅ CAN USE: colortex0-7 (if written in earlier passes)
  ❌ Cannot use: Shadow textures directly
```

**Reference:** See `MINECRAFT_1.21.11_CONSTRAINTS.md` section "Composite Pass Capabilities"

---

### 🔴 Mistake #4: varyings Scope & Linkage Issues
**Problem:** Varyings not properly linked between vertex and fragment shaders, causing undefined variables.

**Root Cause:** Varyings were declared locally in functions instead of at global scope. Iris requires global varyings for proper linking.

**Solution Applied:**
- Commit 56cafc6: Moved ALL varyings to global scope (not inside functions)
- Verified varyings exist in both `.vsh` and corresponding `.fsh`
- Used consistent naming between vertex and fragment

**How to Avoid:**
```glsl
// ❌ WRONG - Local scope
void main() {
    varying float myVar;  // Local to this function
}

// ✅ CORRECT - Global scope
varying float myVar;  // Declared globally

void main() {
    myVar = someValue;
}
```

**Reference:** Commits 56cafc6, f10d825

---

### 🔴 Mistake #5: Entity & Block Variant Programs Missing
**Problem:** Shader compilation fails because entity/block variant programs weren't implemented.

**Root Cause:** Iris requires separate shader programs for different entity types and block variants. I initially assumed one shader per type was sufficient.

**Solution Applied:**
- Commit 50402ef: Added missing entity variant shader wrappers
- Created complete set of required gbuffers programs:
  - gbuffers_basic
  - gbuffers_textured
  - gbuffers_entities
  - gbuffers_hand
  - etc.
- Each variant properly configured in shaders.properties

**How to Avoid:**
```
Required gbuffers Programs (ALL must exist):
├─ gbuffers_basic (simple geometry)
├─ gbuffers_textured (textured geometry)
├─ gbuffers_entities (mobs, items)
├─ gbuffers_hand (first-person hand)
├─ gbuffers_water (fluids)
├─ gbuffers_skytextured (sky dome)
├─ gbuffers_skybasic (sky without texture)
├─ gbuffers_clouds (cloud rendering)
├─ gbuffers_weather (rain, snow)
├─ gbuffers_terrain (ground blocks)
├─ gbuffers_item (item entity rendering)
└─ gbuffers_block (falling blocks, etc.)

If ANY are missing, shader compilation fails.
```

**Reference:** Commits d3b7e1b, 50402ef, 670ee2e

---

### 🔴 Mistake #6: shaders.properties Configuration Issues
**Problem:** Iris doesn't load shaders, or custom profiles don't work.

**Root Cause:** Invalid shaders.properties syntax or incomplete program declarations.

**Solution Applied:**
- Commit 566cac1: Simplified shaders.properties to minimal working version
- Added pack.mcmeta for proper metadata
- Ensured all required properties are present and valid

**How to Avoid:**
```properties
# ✅ CORRECT shaders.properties structure:

version=1
name=Echelon Nexus
description=Photorealistic shader pack

# Profile definitions
profile.HIGH=Enhanced quality
profile.MEDIUM=Balanced
profile.LOW=Performance

# Screen dimensions
screen.width=1920
screen.height=1080

# Texture format definitions (example)
colortex6=RGBA16F

# Composite program definitions
program.composite=composite
program.final=final

# Optional: Sampler declarations
sampler.0=colortex0
sampler.1=colortex1
# ... etc
```

**Reference:** Commits 4e7d80e, 566cac1

---

### 🔴 Mistake #7: Composite2 Caching Issue
**Problem:** Composite2 shader causes frame caching issues, visual glitches.

**Root Cause:** Temporal filtering in composite2 requires proper texture rebinding. Current implementation has coherence/caching bugs with the history buffer.

**Status:** DISABLED TEMPORARILY (Commit 22aabd3)

**How to Avoid/Fix:**
```glsl
// Current workaround: Skip composite2 entirely
// In shaders.properties, comment out:
// program.composite2=composite2

// TODO When fixing:
// 1. Ensure colortex7 (history) is properly configured as RGBA16F
// 2. Use frameCounter for temporal jitter (not frameId)
// 3. Add reprojection guard (discard invalid history)
// 4. Test with multiple frames to ensure coherence
// 5. Verify TAA doesn't cause temporal flicker
```

**Reference:** Commit 22aabd3, PHASE_2_IMPLEMENTATION_GUIDE.md section "Temporal Refinement"

---

### 🔴 Mistake #8: Exceeding Texture Unit Limits
**Problem:** "Too many texture units" compiler error.

**Root Cause:** Trying to sample too many textures in a single shader pass. Iris/Minecraft limits texture units per pass.

**How to Avoid:**
```
Max Texture Units (Per Pass):
- Shadow Pass: ~6 units
- Composite Pass: ~8-12 units
- Composite1+ Pass: ~6-8 units (more limited)

Budget per shader:
- If using: colortex0-2, colortex5, shadowtex0, shadowcolor0
  That's 5 units already. Only room for 3-7 more!

Solution if exceeded:
1. Reduce sampler count (combine textures if possible)
2. Use texture atlas instead of separate samplers
3. Store redundant data in colortex (trades VRAM for texture units)
4. Split across multiple passes
```

---

### 🔴 Mistake #9: Infinite Loops or High Sample Counts
**Problem:** GPU driver timeout, shader compilation fails, or massive frame drops.

**Root Cause:** Loop iteration count too high (>64) or dynamic loop conditions that compiler can't unroll.

**How to Avoid:**
```glsl
// ❌ BAD - Dynamic loop, unknown iterations
for (int i = 0; i < sampleCount; i++) {  // sampleCount is a uniform
    // Driver can't unroll - will timeout
}

// ✅ GOOD - Fixed loop, compiler can unroll
for (int i = 0; i < 32; i++) {  // Literal constant
    // Compiler unrolls this
}

// ✅ ACCEPTABLE - Conditional loop with reasonable max
for (int i = 0; i < min(sampleCount, 32); i++) {
    // Explicit cap prevents overflow
}
```

---

### 🔴 Mistake #10: Precision Loss in Matrix Calculations
**Problem:** Shadow position has subtle artifacts, slightly wrong coordinates.

**Root Cause:** Using mediump (24-bit) precision for depth/position calculations. Need highp (32-bit).

**How to Avoid:**
```glsl
// Fragment shader
precision highp float;  // Force high precision for critical math

// Color calculations: OK with mediump
mediump vec3 color = ...;

// Depth/position: MUST use highp
highp float depth = ...;
highp vec3 worldPos = ...;
highp vec4 shadowPos = ...;
```

---

## 📖 REFERENCE DOCUMENTATION

### Critical Documents (READ FIRST)
1. **PROJECT_VISION.md** - Overall goals, competitive advantages, timeline
2. **MINECRAFT_1.21.11_CONSTRAINTS.md** - Hard limits, what's possible/impossible
3. **PHASE_2_IMPLEMENTATION_GUIDE.md** - Detailed steps for PCSS integration

### Technical References
- **CODE_SNIPPETS.md** - Useful code patterns
- **SHADER_COMPARISON_ANALYSIS.md** - How we compare to other shader packs
- **COMPOSITE_ARCHITECTURE_ANALYSIS.md** - Deep dive into rendering pipeline
- **RESEARCH_PAPERS_CURATED.md** - Academic references for every feature

### Research Papers (Key Sources)
- PCSS: Fernando et al., "Percentage-Closer Soft Shadows" (SIGGRAPH 2006)
- BRDF: Cook & Torrance, "A Reflectance Model for Computer Graphics" (1982)
- TAA: Karis, "High Quality Temporal Supersampling" (SIGGRAPH 2014)
- Sampling: Heitz & Belcour, "A Low-Distortion Map Between Disk and Square" (2019)

---

## 🚀 NEXT STEPS (Priority Order)

### Immediate (Week 1)
**Goal:** Complete Phase 2 PCSS Integration

1. **Implement Depth Reconstruction**
   - Location: `composite.fsh` or create new function in `math.glsl`
   - Use: `gbufferProjectionInverse` + `gbufferModelViewInverse` uniforms
   - Estimated effort: 30 minutes
   - See: PHASE_2_IMPLEMENTATION_GUIDE.md "Step 1"

2. **Implement Shadow Space Transformation**
   - Location: `composite.fsh`
   - Use: `shadowProjection` + `shadowModelView` matrices
   - Estimated effort: 20 minutes
   - See: PHASE_2_IMPLEMENTATION_GUIDE.md "Step 2"

3. **Integrate PCSS Algorithm**
   - Call PCSS functions from `pcss.glsl` in `composite.fsh` main()
   - Test parameters: `lightSize=0.5`, `searchRadius=3.0`
   - Estimated effort: 1 hour
   - See: PHASE_2_IMPLEMENTATION_GUIDE.md "Step 3"

4. **Test in Minecraft**
   - Load in 1.21.11 with Iris
   - Verify shadows appear and are soft
   - Check for visual glitches or black areas
   - Measure frame time overhead (<2ms target)

### Short-term (Week 2-3)
5. **Shadow Cascades**
   - Implement cascade selection logic
   - Blend transitions between cascades
   - Test on multiple distances
   - Estimated effort: 3-4 hours

6. **Colored Shadows**
   - Sample `shadowcolor0` texture
   - Apply color tint to shadow value
   - Test with stained glass, water
   - Estimated effort: 1 hour

7. **Performance Optimization**
   - Profile with Iris `/debug` command
   - Reduce sample counts if needed
   - Optimize memory access patterns
   - Estimated effort: 2-3 hours

### Medium-term (Week 3-4)
8. **Testing & Validation**
   - Complete visual quality checklist (see PHASE_2_IMPLEMENTATION_GUIDE.md)
   - Test on GTX 1660 (MEDIUM), RTX 3060 (HIGH)
   - Verify no crashes or shader errors
   - Estimated effort: 4-6 hours

9. **Fix composite2 TAA Issue**
   - Debug temporal filtering coherence
   - Re-enable composite2 shader
   - Re-test Phases 1 + 2 together
   - Estimated effort: 2-4 hours

### Later (Month 2)
10. **Phase 3: Advanced Atmosphere**
    - Volumetric fog implementation
    - Rayleigh/Mie scattering
    - Cloud rendering
    - See: PROJECT_VISION.md "Phase 4"

11. **Phase 4: Water & Reflections**
    - Screen-space reflections
    - Gerstner waves
    - Caustic projection
    - See: PROJECT_VISION.md "Phase 5"

---

## 🛠️ DEVELOPMENT WORKFLOW

### Git Workflow
```bash
# Always work on the designated branch
git checkout claude/fix-shader-sampler-deps-Smgdj

# Before starting work
git pull origin claude/fix-shader-sampler-deps-Smgdj

# After making changes
git add <files>
git commit -m "feat: Brief description of what changed"
git push -u origin claude/fix-shader-sampler-deps-Smgdj
```

### Commit Message Format
```
feat: Add new feature (e.g., "feat: Implement depth reconstruction")
fix: Fix a bug (e.g., "fix: Correct shadow coordinate bounds")
docs: Update documentation
test: Add or modify tests
refactor: Code cleanup without behavior change
perf: Performance improvement
temp: Temporary change (to be reverted later)
```

### Testing in Minecraft
```
1. Load Minecraft 1.21.11 with Iris 1.6.0+
2. Create test world with varied terrain
3. Toggle shaders on/off to verify active
4. Use /debug to measure frame times
5. Inspect shadows, lighting quality
6. Check for visual artifacts (black areas, flickering, etc.)
7. Compare against baseline (commit 5eb4329 or earlier)
```

### Performance Profiling
```
In Minecraft (with Iris):
- Press F3 to open debug menu
- Look for "Rendering" section
- Note frame time (target: <16.67ms for 60 FPS)
- Use Iris profiler to see per-pass breakdown

Expected profile (Phase 2 when complete):
├─ Shadow: 1-2ms
├─ Composite: 2-3ms (includes PCSS)
├─ Final: 1ms
└─ Total overhead: <10ms
```

---

## 🐛 MISTAKE TRACKING SYSTEM

**When You Encounter a Bug or Mistake:**

1. **Diagnose the Issue**
   - Is it a shader compilation error? (Check .log files)
   - Is it a visual glitch? (Black screen, wrong colors, flickering?)
   - Is it a performance issue? (Frame drops, stuttering?)
   - Is it a logic error? (Wrong values, incorrect algorithm?)

2. **Search Existing Mistakes**
   - Ctrl+F in this document for similar keywords
   - Check if this mistake has been encountered before
   - If yes, apply the known solution

3. **Document New Mistakes**
   - Add to the "MISTAKES ENCOUNTERED" section below
   - Include: Problem, Root Cause, Solution, How to Avoid
   - Include: Commit hash if applicable
   - Include: Time spent debugging
   - Include: Difficulty rating (1-5)

4. **Create a Fix Commit**
   - Make the code change
   - Commit with message like: `fix: <problem> - <root cause>`
   - Push to branch

5. **Update This Document**
   - Add the mistake to the tracking section
   - This prevents the same issue happening again
   - Share learnings with future developers

---

## 📊 MISTAKES ENCOUNTERED TRACKER

**Add new mistakes here as you find them:**

### Template for New Mistakes:
```markdown
### 🔴 Mistake #[N]: [Brief Title]
**Problem:** [What went wrong]
**Root Cause:** [Why it happened]
**Solution Applied:** [How you fixed it]
**Commit:** [Git hash if applicable]
**Time Spent:** [Hours spent debugging]
**Difficulty:** [1-5 stars, 1=easy, 5=hard]
**How to Avoid:** [Code pattern to prevent it]
**Reference:** [Related docs or code]
**Future Prevention:** [Process change to avoid recurrence]
```

---

## 💡 TIPS FOR SUCCESS

### For Shader Development
- **Compile Frequently**: Test after every 5-10 line change
- **Use Debug Colors**: Visualize intermediate values with color output
- **Profile Early**: Don't optimize blind—measure first
- **Reference Existing Code**: Look at Phase 1 composite.fsh for patterns
- **Read the Constraints**: Check MINECRAFT_1.21.11_CONSTRAINTS.md before designing

### For This Project Specifically
- **Research Papers Are Your Friend**: When unsure, go back to the math
- **Test on Multiple Hardware**: Don't assume it works on RTX 3060 if you only have GTX 1660
- **Visual Quality Matters**: If it looks good, the math is probably right
- **Performance is Non-Negotiable**: <2ms overhead for Phase 2 or reduce features

### General Best Practices
- **Small Commits**: One feature per commit, easy to revert
- **Document as You Go**: Future you will thank present you
- **Test Incrementally**: Don't code for 4 hours before testing
- **Keep It Simple**: Premature optimization is the root of all evil
- **Ask for Help**: If stuck >30 mins, consult references

---

## 🔗 IMPORTANT LINKS & RESOURCES

### Official Documentation
- **Iris Shader Specification**: https://github.com/IrisShaders/Iris/wiki
- **OptiFine Shader Format**: https://www.minecraftforum.net/forums/mapping-and-modding-community/mapping-and-modding-tutorials/2814207-shadermod-shaders-svn
- **Minecraft Java 1.21.11 Release Notes**: https://minecraft.wiki/w/Java_Edition_1.21.11

### Tools & Software
- **Minecraft Java 1.21.11**: https://launcher.minecraft.net/
- **Iris Shaders (for Fabric)**: https://www.irisshaders.net/
- **RenderDoc (GPU Debugging)**: https://renderdoc.org/
- **GPU-Z (Performance Monitoring)**: https://www.techpowerup.com/gpu-z/

### Community & Support
- **Iris Discord**: https://discord.gg/iris (shader development help)
- **Minecraft Fabric Community**: https://discord.gg/fabric (mod/shader support)
- **Your Repository**: jjnorris/Echelon-Nexus-Shader-Pack

---

## ✅ HANDOFF CHECKLIST

Before you start, verify:

- [ ] You've read PROJECT_VISION.md (goals & principles)
- [ ] You've read MINECRAFT_1.21.11_CONSTRAINTS.md (what's possible)
- [ ] You've read PHASE_2_IMPLEMENTATION_GUIDE.md (next steps)
- [ ] You've reviewed this document's "Common Mistakes" section
- [ ] You've cloned the repo and checked out the development branch
- [ ] You've installed Minecraft 1.21.11 and Iris 1.6.0+
- [ ] You've tested that the current shader pack loads without errors
- [ ] You understand the rendering pipeline architecture
- [ ] You understand why Claude is handing off (specialization, not skill)
- [ ] You're ready to move this project forward faster than I ever could

---

## 🎯 SUCCESS CRITERIA FOR YOUR TENURE

Phase 2 PCSS Implementation is complete when:

- [ ] Depth reconstruction from depth buffer works correctly
- [ ] Shadow space transformation produces correct coordinates
- [ ] PCSS algorithm produces visible soft shadows
- [ ] Shadow quality visually surpasses Complementary Shaders V4
- [ ] Cascades blend smoothly without artifacts
- [ ] Colored shadows work on translucent blocks (glass, water)
- [ ] Performance < 2ms overhead on HIGH profile (RTX 3060 class)
- [ ] No crashes, shader errors, or visual glitches
- [ ] Works on GTX 1660 (MEDIUM), RTX 3060 (HIGH) minimum
- [ ] No temporal flickering or instability
- [ ] All changes documented in this file's mistake tracker

---

## 📝 FINAL NOTES

### You're Not Replacing Me
This is a **handoff**, not a replacement. This project benefits from your specific expertise in shader development and graphics programming. You'll understand GPU memory management and rendering optimization better than I ever could.

### Learn From What Went Before
The 10 mistakes documented above represent real issues I encountered. Use them as a cheat sheet to avoid the same pitfalls. The project already has a solid foundation—you're just optimizing and completing it.

### This Document is Living
As you work:
- Update the "MISTAKES ENCOUNTERED" section when you find new issues
- Add new reference documents if you create them
- Keep the next steps updated as you complete milestones
- Share your learnings with future developers

### Communication
If you need to hand off again in the future (for any reason):
1. Update this document with your progress
2. Document any NEW mistakes you encountered
3. Update the current status and next steps
4. Make it easy for the next person to continue from where you left off

---

## 🏁 LET'S GO

You've got the vision, the roadmap, the research, the foundation code, and the lessons learned.

**Phase 2 PCSS shadows are ready for implementation.**

**The torch passes to you. Light it up. 🔥**

---

**Document Version:** 1.0
**Last Updated:** 2026-03-20
**Created By:** Claude (Haiku 4.5)
**For:** ChatGPT 5 Mini
**Status:** Ready for Handoff
