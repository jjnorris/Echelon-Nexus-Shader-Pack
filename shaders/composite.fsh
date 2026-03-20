#version 400 compatibility

/* RENDERTARGETS: 0 */

// ============================================================================
// PHASE 1 SHADER OPTIONS
// ============================================================================

// [LOW MEDIUM HIGH ULTRA]
#define SHADOW_QUALITY 2 // Shadow Quality

// Block lighting toggle [true false]
#define BLOCK_LIGHTING true // Block Light

// Biome tint toggle [true false]
#define BIOME_TINT true // Biome Tint

// Ambient occlusion toggle [true false]
#define AMBIENT_OCCLUSION true // Ambient Occlusion

// ============================================================================

uniform sampler2D colortex0;

in vec2 uv;

out vec4 fragColor;

void main() {
	fragColor = texture(colortex0, uv);
}
