// Minimal Phase 1: Render textured geometry to G-Buffer
// Iris Spec: gbuffers_textured renders particles and basic textured geometry

#ifdef VSH

attribute vec3 vaPosition;
attribute vec4 vaColor;
attribute vec2 vaUV0;
attribute ivec2 vaUV2;
attribute vec3 vaNormal;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat3 normalMatrix;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 vertexColor;
varying vec3 normal;

void main() {
	gl_Position = gbufferProjection * (gbufferModelView * vec4(vaPosition, 1.0));

	texCoord = vaUV0;
	lmCoord = vaUV2 / 256.0;  // Normalize lightmap coords
	vertexColor = vaColor;
	normal = normalize(normalMatrix * vaNormal);
}

#endif

#ifdef FSH

uniform sampler2D texture;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 vertexColor;
varying vec3 normal;

/* RENDERTARGETS:0 */

void main() {
	// Sample texture and apply vertex color
	vec4 texColor = texture2D(texture, texCoord) * vertexColor;

	// Discard transparent pixels
	if (texColor.a < 0.1) discard;

	// Output: color with lightmap data
	gl_FragData[0] = texColor;
}

#endif
