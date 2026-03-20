#version 400 compatibility

/* RENDERTARGETS: 5 */

/* PHASE 2: PCSS SHADOWS COMPOSITE PASS

   Input: G-Buffer from Phase 1
   - colortex0: Base color from gbuffers
   - depthtex0: Scene depth

   Processing:
   - Calculate shadow map coordinates
   - Apply PCSS three-stage algorithm
   - Blend shadowed areas

   Output: colortex5 (lit scene for Phase 3 TAA)
*/

#include "/lib/pcss.glsl"

uniform sampler2D colortex0;      // G-Buffer color
uniform sampler2D depthtex0;      // Scene depth
uniform sampler2D shadowtex0;     // Shadow map
uniform sampler2D shadowcolor0;   // Colored shadow data

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

in vec2 uv;

out vec4 fragColor;

void main() {
	// Load G-Buffer data
	vec4 baseColor = texture(colortex0, uv);
	float depth = texture(depthtex0, uv).r;

	// Early exit for sky
	if (depth > 0.9999) {
		fragColor = baseColor;
		return;
	}

	// For Phase 2, we're just adding shadow information
	// Full lighting will come in Phase 3+ with BRDF

	// TODO: Reconstruct world position from depth
	// TODO: Project to shadow space
	// TODO: Calculate PCSS shadow

	// For now, pass through to next phase
	fragColor = baseColor;
}
