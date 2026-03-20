// ============================================================================
// GBUFFERS_CLOUDS IMPLEMENTATION
// Phase 1: Foundation - Cloud Rendering
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Render vanilla clouds with smoothing

// ============================================================================
// VERTEX SHADER SECTION
// ============================================================================
#ifdef VSH

in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

varying vec4 vertexColor;
varying vec2 texCoord;

void main() {
	gl_Position = gbufferProjection * (gbufferModelView * vec4(vaPosition, 1.0));
	vertexColor = vaColor;
	texCoord = vaUV0;
}

#endif // VSH

// ============================================================================
// FRAGMENT SHADER SECTION
// ============================================================================
#ifdef FSH

varying vec4 vertexColor;
varying vec2 texCoord;

uniform sampler2D tex;

/* RENDERTARGETS:0,1,2,3,4 */

void main() {
	vec4 cloud = texture2D(tex, texCoord) * vertexColor;

	if (cloud.a < 0.1) {
		discard;
	}

	// ===== OUTPUT TO G-BUFFERS =====
	// Clouds are lit from top, white color

	gl_FragData[0] = vec4(cloud.rgb, 1.0);

	// Cloud depth (slightly closer than sky)
	gl_FragData[1] = vec4(0.95, 0.0, 0.0, 1.0);

	gl_FragData[2] = vec4(0.5, 1.0, 0.5, 1.0);  // Up normal

	gl_FragData[4] = vec4(0.0, 0.0, 1.0, 1.0);  // Max sky light
	gl_FragData[3] = vec4(0.0);
}

#endif // FSH
