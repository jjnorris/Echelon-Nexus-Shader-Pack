# Claude Code Workflow & Quality Assurance Guidelines
## Echelon Nexus Shader Pack Development

**CRITICAL: This document MUST be referenced for EVERY task, query, and code modification.**

---

## 1. REFERENCE MATERIALS - REQUIRED FIRST STEP

Before creating, modifying, or troubleshooting ANY shader file, you MUST:

### 1.1 Primary References (In Order of Authority)
1. **Complementary Shaders V4** - https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
   - Fetch and examine actual shader implementations
   - Reference their shaders.properties structure
   - Study their composite pass architecture
   - Copy proven working patterns

2. **Photon Shaders** - https://github.com/sixthsurge/photon
   - High-quality implementation patterns
   - Advanced techniques reference
   - Optimization strategies

3. **Shadow Tutorial** - https://github.com/shaderLABS/Shadow-Tutorial
   - Shadow rendering fundamentals
   - Pass structure examples
   - Transformation math reference

4. **OptiFine Documentation** - https://raw.githubusercontent.com/sp614x/optifine/master/OptiFineDoc/doc/shaders.txt
   - Official specification for shader properties
   - Uniform availability per pass
   - Composite pass limitations

### 1.2 Reference Verification Procedure
- [ ] Fetch source code from reference repository
- [ ] Examine the exact structure of similar shaders
- [ ] Verify which uniforms/samplers are available in each pass
- [ ] Copy working patterns, NOT invent new ones
- [ ] Document the reference in code comments

---

## 2. FILE CREATION RULES

### 2.1 Before Creating Any New Shader File
1. **Check References First**
   - Look at how Complementary Shaders implements similar files
   - Examine Photon Shaders for the same functionality
   - Copy the structure exactly

2. **Validate Against Iris/OptiFine Spec**
   - Confirm the pass type exists in OptiFine docs
   - Verify available uniforms for that pass
   - Check texture availability per pass

3. **Never Invent**
   - Do NOT assume how passes should be structured
   - Do NOT guess at uniform availability
   - Do NOT create new patterns without reference

### 2.2 File Naming Requirements
- Composite passes MUST be sequential: `composite`, `composite1`, `composite2`, etc.
- NO gaps in numbering (composite, composite2, composite4 is WRONG)
- Vertex and fragment shaders must match: `composite.fsh` + `composite.vsh`
- Program includes must match: `composite.fsh` includes `/program/composite.glsl`

### 2.3 Include Guard Requirements
Every `.glsl` file MUST have:
```glsl
#ifndef INCLUDED_COMPOSITE1
#define INCLUDED_COMPOSITE1

// ... code ...

#endif // INCLUDED_COMPOSITE1
```

The guard name MUST match the filename and pass number.

---

## 3. COMPOSITE PASS STRUCTURE RULES

### 3.1 Standard Composite Pass Pattern (from Complementary Shaders)
```glsl
#version 130

// COMPOSITE[N] FRAGMENT SHADER - Phase [N]: [Description]
//
// Reference: [GitHub link to similar shader]
//
// Purpose: [What this pass does]

#define OVERWORLD
#define FSH
#include "/program/composite[N].glsl"
```

### 3.2 Uniform Availability by Pass (Iris/OptiFine Standard)

**Composite Pass (Phase 1 - Shadows):**
- ✓ shadowtex0, shadowtex1, shadowcolor0
- ✓ gcolor, gdepth, gnormal, gaux1
- ✓ Shadow matrices (shadowProjection, shadowModelView)
- ✓ Lighting uniforms (sunPosition, moonPosition, etc.)

**Composite1 Pass (Phase 2 - Effects):**
- ✓ composite (previous pass output)
- ✓ gcolor, gdepth, gnormal, gaux1
- ⚠ Shadow textures may NOT be available
- ⚠ Shadow matrices may NOT be available
- ✓ View/projection matrices

**Composite2+ Passes (Post-Processing):**
- ✓ composite[N-1] (previous pass)
- ✓ Custom colortex buffers (colortex0-8)
- ✓ Temporal uniforms (frameCounter, etc.)
- ✗ Shadow textures likely unavailable
- ✗ G-buffer may not be available

### 3.3 Pass Chaining Rules
- Composite reads from G-Buffer and shadowtex
- Composite1 reads from composite output (NOT shadow textures)
- Composite2 reads from composite1 output
- Each pass outputs to screen

---

## 4. SHADER COMPILATION ERROR DEBUGGING

### 4.1 "no program defined" Error
This ALWAYS means one of:
1. The shader structure is malformed
2. Include files aren't being found
3. The main() function isn't visible (due to #ifdef issues)
4. Uniforms/samplers aren't available in that pass

**Debug Procedure:**
1. Simplify the shader to minimal pass-through (texture2D output only)
2. Verify it compiles
3. Add complexity one function at a time
4. When it breaks, that's the issue

### 4.2 "undefined variable" Error
- Check if function is defined BEFORE it's called
- Move function definitions before function calls
- Verify include files contain the function

### 4.3 Type Mismatch Errors
- screenSize is `ivec2` in Iris, cast to `vec2(screenSize)` when needed
- Verify all sampler uniforms match their usage
- Check texture sampling function parameters

---

## 5. SHADERS.PROPERTIES RULES

### 5.1 Composite Pass Configuration
```properties
# Format:
program.composite[N].enabled=[FEATURE_FLAG or true]

# Example:
program.composite.enabled=SHADOW_QUALITY        # Phase 1 - Always if shadows
program.composite1.enabled=SHADOW_QUALITY       # Phase 2 - If shadows
program.composite2.enabled=true                 # Phase 3 - Always
```

### 5.2 Buffer Configuration
Every custom buffer MUST have format AND mipmap settings:
```properties
const int colortex7Format = RGBA16F;
const bool colortex7Mipmap = false;
```

### 5.3 Feature Flag Rules
- Flags MUST be defined before use
- Composite pass enables MUST match actual implementation
- NO enabling passes that don't exist

---

## 6. GIT WORKFLOW RULES

### 6.1 Commit Requirements
Before committing:
- [ ] All files compile without errors
- [ ] References are documented in code
- [ ] Filenames follow sequential naming
- [ ] Include guards match filenames
- [ ] shaders.properties is updated

### 6.2 Commit Message Format
```
[Component]: [Change description]

- Bullet point of what was fixed/added
- Explanation of why (reference to GitHub if needed)

https://claude.ai/code/session_[SESSION_ID]
```

### 6.3 Push Requirements
- Branch name MUST start with `claude/` and end with session ID
- Use: `git push -u origin claude/[description]-[SESSION_ID]`
- Verify push succeeds before continuing

---

## 7. CODE QUALITY CHECKLIST

Every modification MUST pass:

### 7.1 Structure Check
- [ ] File naming is sequential (composite, composite1, composite2)
- [ ] All `.fsh` files have matching `.vsh` files
- [ ] All `.fsh` files have matching `.glsl` includes
- [ ] Include guards are present and correct
- [ ] #ifdef FSH / #endif wrapping is correct

### 7.2 Reference Check
- [ ] Similar implementation fetched from reference repos
- [ ] Code patterns match established implementations
- [ ] No invented patterns or assumptions

### 7.3 Uniform Check
- [ ] All sampler uniforms are available in that pass
- [ ] Shadow uniforms only used in composite (not composite1+)
- [ ] Type casting correct (ivec2 → vec2, etc.)

### 7.4 Compilation Check
- [ ] Shader compiles to at least pass-through version
- [ ] All includes resolve correctly
- [ ] All function calls have definitions above them
- [ ] No forward references in library functions

### 7.5 Integration Check
- [ ] shaders.properties correctly enables/disables passes
- [ ] Buffer formats defined for all custom textures
- [ ] Feature flags properly configured

---

## 8. TROUBLESHOOTING DECISION TREE

**Error: "no program defined"**
→ Simplify shader to pass-through → Test → Add back complexity piece by piece

**Error: "undefined variable"**
→ Check if function defined before use → Check includes → Verify reference

**Error: "no matching overload"**
→ Check parameter types → Verify sampler declarations → Look at reference implementation

**Error: "uniform not found"**
→ Check if available in that pass → Don't use shadow uniforms in composite1+ → Check OptiFine spec

**Shader won't load**
→ Check filename matches expected pattern → Verify shaders.properties enables it → Check include paths

---

## 9. REFERENCE IMPLEMENTATION CHECKLIST

When implementing ANY new functionality:

1. **Find Example**
   - [ ] Locate implementation in Complementary/Photon/Shadow Tutorial
   - [ ] Fetch actual source code
   - [ ] Study the structure

2. **Copy Pattern**
   - [ ] Copy header comments and references
   - [ ] Copy uniform declarations
   - [ ] Copy function signatures
   - [ ] Copy include statements

3. **Adapt for Our Use**
   - [ ] Change identifiers to match our naming
   - [ ] Adjust for our phase structure
   - [ ] Update comments with our purpose

4. **Verify Against Spec**
   - [ ] All uniforms available in this pass (check OptiFine spec)
   - [ ] All includes exist in our lib/
   - [ ] All external functions defined

5. **Test Compilation**
   - [ ] Shader compiles
   - [ ] All includes resolve
   - [ ] No undefined errors

---

## 10. PROHIBITED ACTIONS

🚫 DO NOT:
- Create shader files without referencing working examples
- Invent new composite pass names (must be sequential)
- Use shadow uniforms in composite1 or later passes
- Create custom uniform types Iris doesn't support
- Skip include guards or use wrong names
- Enable passes in properties that don't exist
- Commit without verifying compilation

---

## 11. CURRENT PROJECT STATE

**Branch:** `claude/fix-shader-sampler-deps-Smgdj`

**Current Structure:**
- `composite.*` = Phase 1: Shadow/Lighting (✓ Working)
- `composite1.*` = Phase 2: PCSS Soft Shadows (Currently simplified pass-through)
- `composite2.*` = Phase 3: Quantum-Inspired TAA (✓ Ready)

**Active Issues:**
- Composite1 compilation: Need to implement using reference code
- Do NOT use shadowtex in composite1
- Check Complementary Shaders for composite1 bloom/effects implementation

---

## 12. SESSION ID & REFERENCE

**Current Session:** `011dF8GgqCQiK6k2xENRJixC`

**This document version:** v1.0 - Created 2026-03-20

**Last updated:** [UPDATE DATE]

---

**MANDATORY: Print this checklist for every task before starting work.**
