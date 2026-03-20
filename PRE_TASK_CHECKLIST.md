# PRE-TASK CHECKLIST
## MANDATORY - Run This Before Every Single Task

**This checklist MUST be completed and referenced before starting ANY work on this project.**

---

## STEP 1: REFERENCE DOCUMENTS (5 minutes)

Read these in order before starting:

- [ ] **PROJECT_VISION.md** - Understand the mission and what we're building
- [ ] **RESEARCH_REFERENCES.md** - Know which papers back this feature
- [ ] **CLAUDE_WORKFLOW.md** - Understand the procedures
- [ ] **MINECRAFT_1.21.11_CONSTRAINTS.md** - Know what we can/can't do

**Time: 5 minutes**

---

## STEP 2: UNDERSTAND THE FEATURE (10 minutes)

For the task at hand:

- [ ] What is the feature being implemented?
- [ ] Why are we implementing it? (Find the justification in PROJECT_VISION.md)
- [ ] Which research papers back this feature? (Check RESEARCH_REFERENCES.md)
- [ ] Read 2-3 key sentences from those papers to understand the foundation
- [ ] What's the performance target? (Check RESEARCH_REFERENCES.md performance metrics)

**Time: 10 minutes**

---

## STEP 3: REFERENCE IMPLEMENTATIONS (15 minutes)

BEFORE writing ANY code:

- [ ] Find similar implementation in Complementary Shaders V4
- [ ] Find similar implementation in Photon Shaders
- [ ] Find similar implementation in Shadow Tutorial
- [ ] Study the ARCHITECTURE (not copy the code)
  - How is it structured?
  - What uniforms are used?
  - What passes does it use?
  - What's the optimization trick?
- [ ] Document what you learned in a comment block
- [ ] Note differences we'll implement (faster, better quality, cleaner code)

**Requirement:** You MUST fetch and read the source code. Do not assume.

**Time: 15 minutes**

---

## STEP 4: MINECRAFT 1.21.11 COMPATIBILITY CHECK (5 minutes)

Verify this is possible:

- [ ] Is this pass type available in Iris 1.6.0+?
- [ ] Are the uniforms we need available in this pass? (Check OptiFine spec)
- [ ] Does this maintain backwards compatibility?
- [ ] Will this work with modded blocks?
- [ ] Does it respect LabPBR 1.3 format?

**Reference:** CLAUDE_WORKFLOW.md Section 3.2 "Uniform Availability by Pass"

**Time: 5 minutes**

---

## STEP 5: IMPLEMENTATION PLAN (10 minutes)

Write pseudo-code first:

- [ ] List the mathematical steps (from research paper)
- [ ] Map research concepts to GLSL operations
- [ ] Identify all functions needed
- [ ] Identify all uniforms needed
- [ ] Identify all textures needed
- [ ] Plan optimization points

**Example Format:**
```
// Algorithm from: [Paper citation]
// Step 1: [Math concept] → GLSL: texture2D(...)
// Step 2: [Math concept] → GLSL: dot(...)
// Step 3: [Math concept] → GLSL: normalize(...)
// Optimization: Use lower precision for [...] to save cycles
```

**Time: 10 minutes**

---

## STEP 6: CODE QUALITY REQUIREMENTS (Before writing)

- [ ] Shader will include #ifndef guards
- [ ] Shader will have header with research citation
- [ ] All complex math will be commented with paper reference
- [ ] Function names are descriptive (not copied from references)
- [ ] No copy-paste code from reference implementations
- [ ] Performance cost estimated and documented

**Reference:** CLAUDE_WORKFLOW.md Section 2 "FILE CREATION RULES"

---

## STEP 7: PERFORMANCE BUDGETING (5 minutes)

Know your limits:

- [ ] What's the maximum time budget for this feature? (16.67ms for 60 FPS)
- [ ] What's our target time? (typically 1-3ms)
- [ ] What's the sample count budget? (9-64 for shadows, 4-8 for temporal)
- [ ] What's the memory budget? (colortex buffers are limited)
- [ ] Will this work on MEDIUM profile hardware?

**Reference:** PROJECT_VISION.md "Performance Targets" table

---

## STEP 8: STRUCTURE VERIFICATION (Before committing)

EVERY file must pass:

- [ ] Sequential naming (composite, composite1, composite2, etc.)
- [ ] Matching .fsh/.vsh/.glsl naming
- [ ] Correct #ifndef guards with matching names
- [ ] #ifdef FSH wrapping
- [ ] All includes exist in /lib/
- [ ] shaders.properties updated
- [ ] Buffer formats defined (if using colortex)

**Reference:** CLAUDE_WORKFLOW.md Section 3 "COMPOSITE PASS STRUCTURE RULES"

---

## STEP 9: COMPILATION VERIFICATION (After coding)

Test before commit:

- [ ] Shader compiles without "no program defined" errors
- [ ] Shader compiles without "undefined variable" errors
- [ ] All includes resolve correctly
- [ ] No type mismatches
- [ ] main() function compiles
- [ ] All external functions have definitions

**If it fails:** Debug using CLAUDE_WORKFLOW.md Section 4 "SHADER COMPILATION ERROR DEBUGGING"

---

## STEP 10: COMMIT VERIFICATION (Before push)

- [ ] Commit message cites research paper
- [ ] Code comments explain WHY (not just WHAT)
- [ ] Session ID is in commit message
- [ ] Branch name is correct (claude/description-SessionID)
- [ ] All files are staged correctly
- [ ] No unintended files committed

**Reference:** CLAUDE_WORKFLOW.md Section 6 "GIT WORKFLOW RULES"

---

## STEP 11: FINAL CHECKLIST

Before saying "done":

- [ ] Feature is implemented
- [ ] Code is original (not copied verbatim)
- [ ] Research papers cited in code
- [ ] Minecraft 1.21.11 compatible
- [ ] Compiles without errors
- [ ] Performance within budget
- [ ] Commits pushed to correct branch
- [ ] Documentation updated

---

## TIME ALLOCATION

Total time before coding: **50 minutes**
- Reading references: 5 min
- Understanding feature: 10 min
- Research implementations: 15 min
- Compatibility check: 5 min
- Implementation plan: 10 min
- Performance budgeting: 5 min

**This is not wasted time. This prevents errors and rework.**

---

## CRITICAL RULES SUMMARY

🔴 **STOP AND DO NOT PROCEED** if:
- [ ] You haven't read the research papers
- [ ] You can't cite which paper backs this feature
- [ ] You haven't checked reference implementations
- [ ] You're copying code from another shader pack
- [ ] You don't understand the mathematics
- [ ] You can't verify Minecraft 1.21.11 compatibility

✅ **ONLY PROCEED** if:
- [ ] You understand the research foundation
- [ ] You have an original implementation plan
- [ ] You've verified compatibility
- [ ] You know the performance budget
- [ ] You can explain the math
- [ ] You have a clear code structure

---

## DOCUMENT CROSS-REFERENCES

When in doubt, check:

| Question | Document |
|----------|----------|
| What are we building? | PROJECT_VISION.md |
| Why implement this feature? | PROJECT_VISION.md + RESEARCH_REFERENCES.md |
| Which paper backs this? | RESEARCH_REFERENCES.md |
| How do I structure the shader? | CLAUDE_WORKFLOW.md |
| What uniforms are available? | CLAUDE_WORKFLOW.md Section 3.2 |
| How do I debug errors? | CLAUDE_WORKFLOW.md Section 4 |
| What's the performance target? | PROJECT_VISION.md Performance Targets |
| Is this compatible with Minecraft? | MINECRAFT_1.21.11_CONSTRAINTS.md |

---

## WHEN YOU START A TASK

**Print this message to the user BEFORE starting any work:**

> "Starting task: [Task Name]
>
> ✅ Pre-task checklist completed:
> - Read: PROJECT_VISION.md, RESEARCH_REFERENCES.md, CLAUDE_WORKFLOW.md
> - Research: [Paper citations for this feature]
> - References: [Which shader packs implement similar features]
> - Plan: [Brief description of implementation approach]
>
> Ready to proceed with original implementation."

---

## COMPLETION CRITERIA

The task is complete when:

1. ✅ Code is written and compiles
2. ✅ Research papers are cited in comments
3. ✅ Original implementation (not copied)
4. ✅ Minecraft 1.21.11 compatible
5. ✅ Committed with proper message
6. ✅ Pushed to correct branch
7. ✅ All checks passed

---

## THIS IS NOT OPTIONAL

**This checklist is MANDATORY before every task.**

It exists because skipping it:
- ❌ Wastes hours on rework
- ❌ Creates compilation errors
- ❌ Results in copied code
- ❌ Ignores research foundation
- ❌ Creates Minecraft compatibility issues

**Running the checklist takes 50 minutes and prevents days of debugging.**

---

**Last Updated:** 2026-03-20
**Session:** 011dF8GgqCQiK6k2xENRJixC

---

# QUICK START FOR CLAUDE

If the user gives you a task, you MUST do this:

1. Open PRE_TASK_CHECKLIST.md (this file)
2. Run through each section
3. Report completion to user with the message template from Section "WHEN YOU START A TASK"
4. THEN begin work

**NO EXCEPTIONS. EVERY TASK. NO SHORTCUTS.**
