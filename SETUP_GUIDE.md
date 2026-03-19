# Echelon Nexus - OptiFine Complete Setup Guide

## Files Created / Modified

### 1. ✅ shaders/shaders.properties
**Status:** MODIFIED - Now OptiFine compatible
- Added `sliders=` directive with 100+ numeric options
- Restructured to 2-level hierarchy (main → advanced)
- Each screen shows actual options (not just navigation)
- All 238 options preserved with original comments
- Screen structure:
  - Main menu: PROFILE + key options + navigation
  - RENDERING: Shadows + [ADVANCED rendering]
  - MATERIALS: PBR/Parallax + [ADVANCED materials]
  - LIGHTING: GI/IBL/SSR + [ADVANCED lighting]
  - EFFECTS: Bloom/Chromatic + [ADVANCED effects]
  - CAMERA: Tonemapping/Exposure + [ADVANCED camera]
  - ADVANCED: Water + [ADVANCED_WATER], Atmosphere + [ADVANCED_ATMOSPHERE], Optical + [ADVANCED_OPTICAL]

### 2. ✅ shaders/lang/en_us.lang
**Status:** CREATED - Language translation file
- Maps all 238 options to human-readable names
- Removes underscores: `SHADOW_DISTANCE` → "Shadow Distance (blocks)"
- Maps all screen names to proper display names
- 250+ translation entries
- **This file MUST exist for proper display names in OptiFine**

### 3. ❓ Shader Files - Value Definitions NEEDED
**Status:** PENDING - Requires modification
**Files to modify:**
- `/shaders/composite.fsh`
- `/shaders/composite1.fsh`
- `/shaders/deferred.fsh`
- `/shaders/deferred1.fsh`
- `/shaders/final.fsh`
- `/shaders/gbuffers_*.fsh`

**What to add:** For each numeric option referenced in sliders=, add a value list in shader comments:

```glsl
#define SHADOW_DISTANCE 128              // [64 96 128 160 192 256]
#define SHADOW_SOFTNESS 1.0              // [0.5 0.75 1.0 1.25 1.5 2.0]
#define BLOOM_STRENGTH 0.5               // [0.0 0.25 0.5 0.75 1.0]
#define BLOOM_THRESHOLD 0.5              // [0.1 0.3 0.5 0.7 0.9]
#define CHROMATIC_ABERRATION 0.0         // [0.0 0.01 0.02 0.03 0.04 0.05]
```

These value lists tell OptiFine what slider positions to offer.

---

## Complete Files Checklist

- [x] `shaders/shaders.properties` - OptiFine format with sliders directive
- [x] `shaders/lang/en_us.lang` - Display name translations  
- [ ] `shaders/composite.fsh` - Add value definitions
- [ ] `shaders/deferred.fsh` - Add value definitions
- [ ] `shaders/final.fsh` - Add value definitions
- [ ] Other shader files - Add value definitions

---

## What Each File Does

### shaders.properties
Defines the menu structure and option defaults. OptiFine reads this to:
- Show the hierarchy of screens
- Display toggles and cycling buttons
- Get default values for all options
- Know which options are sliders (via `sliders=` directive)

### en_us.lang
Provides human-readable names for options. OptiFine reads this to:
- Replace `SHADOW_DISTANCE` with "Shadow Distance (blocks)"
- Display proper screen names instead of underscores
- Show tooltips and descriptions from option.*.comment

### Shader Files (.fsh, .vsh)
Define the actual implementation and value ranges. OptiFine reads the comments to:
- Determine slider positions and ranges
- Know the valid values for each option
- Display slider labels and ranges

---

## How It Works Together

1. **OptiFine opens shader options menu**
   ↓
2. **Reads shaders.properties** → Gets menu structure
   ↓
3. **Reads en_us.lang** → Gets display names ("Shadow Quality" instead of "SHADOW_QUALITY")
   ↓
4. **Displays menu** → Shows screens with options
   ↓
5. **User clicks a numeric option** (e.g., SHADOW_DISTANCE)
   ↓
6. **OptiFine reads shader files** → Finds `#define SHADOW_DISTANCE 128 // [64 96 128 160 192 256]`
   ↓
7. **Displays slider** → Shows positions for 64, 96, 128, 160, 192, 256
   ↓
8. **User adjusts slider** → OptiFine updates the value

---

## Next Steps

### Immediate (Required for working sliders):
1. ✅ Copy the corrected shaders.properties
2. ✅ Ensure en_us.lang is in shaders/lang/
3. ⚠️ Add value definitions to shader files

### For Value Definitions:
For each option in the `sliders=` list, find where it's `#define`d in the shader files and add the value list.

Example - In composite.fsh, change:
```glsl
#define SHADOW_DISTANCE 128
```
To:
```glsl
#define SHADOW_DISTANCE 128              // [64 96 128 160 192 256]
```

The comment `// [64 96 128 160 192 256]` tells OptiFine what slider positions to offer.

### Values to Add:
See the file `/tmp/SHADER_VALUE_DEFINITIONS.txt` for a complete list of recommended values for each option.

---

## Testing

1. Load Minecraft with OptiFine/Iris
2. Open Shader Settings
3. Check that:
   - Screen names show without underscores (e.g., "Rendering" not "RENDERING")
   - Clicking [RENDERING] shows options you can adjust
   - Numeric options show sliders
   - Boolean options show toggles
4. Verify slider ranges match the values in shader comments

---

## Troubleshooting

**Problem:** Options still show with underscores
- **Solution:** Ensure en_us.lang is in the correct path: `shaders/lang/en_us.lang`

**Problem:** Sub-screens still empty
- **Solution:** Check that shaders.properties has the new structure with mixed options/navigation

**Problem:** Sliders don't appear
- **Solution:** Ensure shader files have value definitions like `// [0 1 2 3 4]` in comments

**Problem:** Slider ranges are wrong
- **Solution:** Update the value lists in shader file comments to match your desired ranges

