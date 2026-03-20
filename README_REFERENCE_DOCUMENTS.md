# REFERENCE DOCUMENTS - Master Index
## Everything Claude Must Know Before Working on This Project

**CRITICAL: This document ties all reference materials together. Read the index below to find what you need.**

---

## QUICK REFERENCE BY TASK TYPE

### "I need to implement a new shader feature"
**Follow this order:**
1. Read: **PRE_TASK_CHECKLIST.md** (entire document - 50 min process)
2. Read: **PROJECT_VISION.md** (mission & roadmap)
3. Reference: **RESEARCH_REFERENCES.md** (find papers for this feature)
4. Reference: **MINECRAFT_1.21.11_CONSTRAINTS.md** (verify it's possible)
5. Reference: **CLAUDE_WORKFLOW.md** (file creation rules)

### "I need to fix a shader compilation error"
**Follow this order:**
1. Reference: **CLAUDE_WORKFLOW.md** Section 4 (Debugging procedures)
2. Reference: **MINECRAFT_1.21.11_CONSTRAINTS.md** (Availability matrix)
3. Check: **MINECRAFT_1.21.11_CONSTRAINTS.md** Section "Shader Pass Capabilities"

### "I'm not sure if a feature is possible"
**Check:**
1. **PROJECT_VISION.md** (Phase roadmap - is it planned?)
2. **MINECRAFT_1.21.11_CONSTRAINTS.md** (Feasibility matrix)
3. **RESEARCH_REFERENCES.md** (What papers back this?)

### "The shader doesn't compile"
**Debug using:**
1. **MINECRAFT_1.21.11_CONSTRAINTS.md** (Hard limits section)
2. **CLAUDE_WORKFLOW.md** Section 4 (Compilation error debugging)
3. **MINECRAFT_1.21.11_CONSTRAINTS.md** (GLSL constraints)

### "I need to optimize performance"
**Reference:**
1. **PROJECT_VISION.md** (Performance targets)
2. **MINECRAFT_1.21.11_CONSTRAINTS.md** (Budget breakdown)
3. **RESEARCH_REFERENCES.md** (Optimization papers)

---

## DOCUMENT DESCRIPTIONS

### 1. PRE_TASK_CHECKLIST.md
**What:** The MANDATORY checklist that must be run before EVERY task
**When:** EVERY SINGLE TASK (no exceptions)
**Time:** 50 minutes (before writing any code)
**Contains:**
- 11-step verification process
- Research paper requirements
- Reference implementation study
- Compatibility checking
- Performance budgeting
- Compilation verification
- Commit requirements

**Key Section:** "WHEN YOU START A TASK" - The message to print to user

**Rule:** Do NOT start ANY work until this checklist is complete.

---

### 2. PROJECT_VISION.md
**What:** The overall vision, mission, and goals of the Echelon Nexus Shader Pack
**When:** Before implementing any feature (to understand context)
**Contains:**
- Mission statement: "Fastest, most beautiful, most efficient"
- Core principles (research-driven, performance-first, original)
- Quality targets (per GPU tier)
- Feature roadmap (7 phases)
- Success criteria
- Competitive advantages

**Key Sections:**
- Quality Targets Table
- Feature Roadmap (current status)
- Timeline & Milestones
- Development Philosophy (What We Do/Don't Do)

**Use For:** Understanding WHY we implement features, not just HOW

---

### 3. RESEARCH_REFERENCES.md
**What:** Academic papers and technical references backing every feature
**When:** Before implementing any feature (to find the papers)
**Contains:**
- Cook-Torrance BRDF references
- PCSS shadow rendering papers
- Temporal Anti-Aliasing (TAA) papers
- Sampling techniques (Halton, blue noise)
- Quantum annealing concepts
- Volumetric rendering
- Screen-space reflections
- Path tracing and Monte Carlo
- Spectral rendering
- Performance optimization papers

**Key Sections:**
- Core Rendering Theory
- Shadow Rendering (both basic and PCSS)
- Temporal Techniques
- Advanced Sampling
- Atmospheric Rendering
- Water & Reflections
- Advanced Features
- Performance Optimization
- Minecraft-Specific Standards

**Format:** Each feature has:
- Reference (paper/book)
- Authors & year
- Topic
- Implementation details
- Why this technique

**Use For:** Finding which papers to cite, understanding the mathematical foundation

---

### 4. MINECRAFT_1.21.11_CONSTRAINTS.md
**What:** Hard constraints, capabilities, and limitations for Minecraft Java 1.21.11 with Iris
**When:** Before designing any feature
**Contains:**
- Complete rendering pipeline diagram
- Hardware capability table
- Texture/buffer limits (colortex0-8)
- Shadow map constraints
- Shader pass capabilities (what's available in each pass)
- GLSL language constraints
- Floating-point precision limits
- Memory and bandwidth requirements
- Feature feasibility matrix (what's possible)
- Performance budget breakdown
- Known issues and limitations
- Hard limits (DO NOT EXCEED)

**Key Sections:**
- "Shader Pass Capabilities" - Know what uniforms are available in each pass
- "Feature Feasibility Matrix" - See if your feature is possible
- "Performance Budget Breakdown" - Know how much time you have
- "Hard Limits" - Never exceed these

**Critical Rule:** Composite1 pass may NOT have shadowtex uniforms available

**Use For:** Verifying a feature is possible before attempting it

---

### 5. CLAUDE_WORKFLOW.md
**What:** Mandatory procedures for every code modification
**When:** Before creating/modifying any file
**Contains:**
- Reference materials (GitHub repos to check)
- File creation rules
- Composite pass structure standards
- Uniform availability per pass
- Pass chaining rules
- Shader compilation error debugging
- shaders.properties rules
- Git workflow rules
- Code quality checklist
- Troubleshooting decision tree
- Reference implementation checklist
- Prohibited actions

**Key Sections:**
- Section 1: REFERENCE MATERIALS (Complementary, Photon, Shadow Tutorial, OptiFine)
- Section 2: FILE CREATION RULES (naming, includes, guards)
- Section 3: COMPOSITE PASS STRUCTURE (uniforms available per pass)
- Section 4: SHADER COMPILATION ERROR DEBUGGING
- Section 9: PROHIBITED ACTIONS (things that cause failures)

**Critical Rule:** Always reference Complementary Shaders V4, Photon, and Shadow Tutorial BEFORE writing code

**Use For:** Ensuring code follows project standards and references

---

## HIERARCHY & DEPENDENCIES

```
┌─────────────────────────────────────────────────────┐
│  PRE_TASK_CHECKLIST.md                             │
│  (Start here EVERY task)                           │
└────────────┬────────────────────────────────────────┘
             │
             ├──→ Read: PROJECT_VISION.md
             │    (Understand the mission)
             │
             ├──→ Read: RESEARCH_REFERENCES.md
             │    (Find papers for this feature)
             │
             ├──→ Read: MINECRAFT_1.21.11_CONSTRAINTS.md
             │    (Verify feasibility)
             │
             ├──→ Read: CLAUDE_WORKFLOW.md
             │    (Learn structure & procedures)
             │
             └──→ Study Reference Implementations
                  (Complementary, Photon, Shadow Tutorial)

             THEN: Implement original code

             THEN: Follow CLAUDE_WORKFLOW.md
                  - Structure checklist
                  - Compilation verification
                  - Git workflow
                  - Commit requirements
```

---

## WHEN TO REFERENCE EACH DOCUMENT

| Situation | Document | Section |
|-----------|----------|---------|
| Starting a new task | PRE_TASK_CHECKLIST.md | All sections |
| Understanding project goals | PROJECT_VISION.md | Mission & Roadmap |
| Finding research papers | RESEARCH_REFERENCES.md | Topic section |
| Checking if feature is possible | MINECRAFT_1.21.11_CONSTRAINTS.md | Feasibility matrix |
| Verifying shader pass uniforms | MINECRAFT_1.21.11_CONSTRAINTS.md | Shader Pass Capabilities |
| Debugging compilation error | CLAUDE_WORKFLOW.md | Section 4 |
| Creating new shader file | CLAUDE_WORKFLOW.md | Section 2 |
| Understanding performance budget | MINECRAFT_1.21.11_CONSTRAINTS.md | Performance Budget |
| Implementing PCSS shadows | RESEARCH_REFERENCES.md | Shadow Rendering |
| Implementing TAA | RESEARCH_REFERENCES.md | Temporal Techniques |
| Implementing anything | PRE_TASK_CHECKLIST.md | Run full checklist |

---

## CRITICAL RULES SUMMARY

### From PRE_TASK_CHECKLIST.md
🔴 **STOP if you haven't:**
- Read the research papers
- Checked reference implementations
- Verified Minecraft 1.21.11 compatibility
- Created an original implementation plan

### From CLAUDE_WORKFLOW.md
🔴 **STOP if you haven't:**
- Studied Complementary Shaders implementation
- Checked OptiFine specification
- Verified uniform availability in this pass
- Understood the file structure

### From MINECRAFT_1.21.11_CONSTRAINTS.md
🔴 **STOP if:**
- Feature is marked as "❌ No" in feasibility matrix
- You're using shadowtex in composite1+
- You're exceeding hard limits
- You're not budgeting performance

### From PROJECT_VISION.md
🔴 **STOP if:**
- Feature isn't backed by research papers
- Implementation is copying another shader pack
- Code doesn't fit the vision
- Performance target can't be met

---

## HOW TO USE THESE DOCUMENTS

### As a Developer (You)
1. Before ANY task: Run PRE_TASK_CHECKLIST.md completely
2. For specific features: Go to Reference Quick Index → find document → reference section
3. When stuck: Use "Troubleshooting Decision Tree" in CLAUDE_WORKFLOW.md
4. When in doubt: Ask "Is this in the reference documents?" and find the answer

### As a User (Checking Claude's Work)
1. Verify Claude ran PRE_TASK_CHECKLIST.md (should be printed at task start)
2. Check that research papers are cited in code comments
3. Verify files follow CLAUDE_WORKFLOW.md structure
4. Confirm Minecraft 1.21.11 compatibility constraints are met

---

## DOCUMENT MAINTENANCE

### When to Update These Documents
- [ ] New research papers discovered
- [ ] New Minecraft/Iris version released
- [ ] New limitations discovered
- [ ] New features implemented
- [ ] Performance targets change
- [ ] New techniques discovered

### Version Control
**Current Version:** 2.0
**Last Updated:** 2026-03-20
**Session:** 011dF8GgqCQiK6k2xENRJixC

---

## THE GOLDEN RULE

> **Every feature implemented in Echelon Nexus Shader Pack must:**
>
> 1. ✅ Follow PRE_TASK_CHECKLIST.md (before starting)
> 2. ✅ Cite research papers from RESEARCH_REFERENCES.md
> 3. ✅ Verify feasibility in MINECRAFT_1.21.11_CONSTRAINTS.md
> 4. ✅ Follow structure from CLAUDE_WORKFLOW.md
> 5. ✅ Achieve vision from PROJECT_VISION.md
> 6. ✅ Be original (study references, don't copy)

---

## QUICK NAVIGATION

**I need to...**

- Implement a new feature → PRE_TASK_CHECKLIST.md
- Understand the project → PROJECT_VISION.md
- Find research papers → RESEARCH_REFERENCES.md
- Check if it's possible → MINECRAFT_1.21.11_CONSTRAINTS.md
- Debug an error → CLAUDE_WORKFLOW.md Section 4
- Create a new file → CLAUDE_WORKFLOW.md Section 2
- Optimize performance → MINECRAFT_1.21.11_CONSTRAINTS.md Performance Budget
- Understand why we do this → PROJECT_VISION.md Development Philosophy

---

**MANDATORY:** Keep this document in mind. Every work session should reference it first.

**Last Updated:** 2026-03-20
**Session:** 011dF8GgqCQiK6k2xENRJixC
