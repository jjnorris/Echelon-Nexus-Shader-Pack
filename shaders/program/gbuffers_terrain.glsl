// Echelon Nexus - Phase 1: Render terrain (solid/cutout blocks)
// Based on Iris pipeline for Minecraft 1.21.11
// Reference: Photon Shaders gbuffers_all_solid pattern

#ifdef VSH

out vec2 uv;
out vec2 light_levels;
out vec4 tint;

void main() {
	// Texture coordinates from vertex data
	uv = gl_MultiTexCoord0.xy;

	// Lightmap coordinates (block light, sky light)
	// gl_MultiTexCoord1 range is 0-240, normalize to 0-1
	light_levels = gl_MultiTexCoord1.xy / 240.0;

	// Vertex color (biome tint, AO)
	tint = gl_Color;

	// Transform vertex position: model space -> view space -> clip space
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}

#endif

#ifdef FSH

in vec2 uv;
in vec2 light_levels;
in vec4 tint;

// gtexture is the standard sampler name for Iris (MC 1.17+)
uniform sampler2D gtexture;
uniform sampler2D lightmap;

/* RENDERTARGETS: 0 */

out vec4 fragColor;

void main() {
	// Sample block texture with biome tint
	vec4 color = texture(gtexture, uv) * tint;

	// Discard fully transparent fragments
	if (color.a < 0.1) discard;

	// Apply vanilla lightmap
	color *= texture(lightmap, light_levels);

	// Output to colortex0
	fragColor = color;
}

#endif
