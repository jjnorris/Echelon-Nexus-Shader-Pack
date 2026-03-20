#version 400 compatibility

/* RENDERTARGETS: 0 */

/* PHASE 2: PCSS SHADOWS COMPOSITE PASS
   Simplified - no includes, inlined PCSS code
*/

uniform sampler2D colortex0;      // G-Buffer color
uniform sampler2D colortex1;      // Phase 1 base lighting
uniform sampler2D depthtex0;      // Scene depth
uniform sampler2D shadowtex0;     // Shadow map

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform vec3 cameraPosition;

in vec2 uv;
out vec4 fragColor;

// Poisson disk pattern for shadow sampling
const vec2 poissonDisk16[16] = vec2[](
	vec2(-0.94201624,  -0.39906216),
	vec2( 0.94558609,  -0.76890725),
	vec2(-0.74205544,  -0.94693636),
	vec2( 0.34495938,   0.29387760),
	vec2(-0.91588581,   0.45771432),
	vec2(-0.03617221,  -0.99518287),
	vec2( 0.81479360,   0.41529015),
	vec2( 0.78512320,  -0.64545042),
	vec2(-0.48821436,   0.04532837),
	vec2(-0.87421629,   0.19379118),
	vec2(-0.30331618,   0.47817620),
	vec2( 0.14918677,   0.87314927),
	vec2( 0.48140316,   0.15541062),
	vec2( 0.11003546,   0.44798897),
	vec2(-0.61149926,   0.78995058),
	vec2( 0.13168975,  -0.04332821)
);

// Blocker search
vec3 blockerSearch(vec2 coord, float receiverDepth, float searchRadius) {
	float avgBlockerDepth = 0.0;
	float blockerCount = 0.0;

	for (int i = 0; i < 16; i++) {
		vec2 offset = poissonDisk16[i] * searchRadius;
		vec2 samplePos = clamp(coord + offset, vec2(0.0), vec2(1.0));
		float depth = texture(shadowtex0, samplePos).x;

		if (depth < receiverDepth) {
			avgBlockerDepth += depth;
			blockerCount += 1.0;
		}
	}

	if (blockerCount > 0.0) {
		avgBlockerDepth /= blockerCount;
	}

	return vec3(avgBlockerDepth, blockerCount, searchRadius);
}

// Penumbra estimation
float computePenumbra(float avgBlockerDepth, float receiverDepth, float lightSize) {
	float penumbraDistance = receiverDepth - avgBlockerDepth;
	if (penumbraDistance <= 0.0) return 0.0;
	float penumbraWidth = (penumbraDistance / avgBlockerDepth) * lightSize;
	return clamp(penumbraWidth, 0.0, 1.0);
}

// PCF sampling
float pcfShadow(vec2 coord, float receiverDepth, float filterSize, int sampleCount) {
	float shadow = 0.0;

	for (int i = 0; i < 16; i++) {
		if (i >= sampleCount) break;
		vec2 offset = poissonDisk16[i] * filterSize;
		vec2 samplePos = clamp(coord + offset, vec2(0.0), vec2(1.0));
		float depth = texture(shadowtex0, samplePos).x;
		shadow += (depth >= receiverDepth) ? 1.0 : 0.0;
	}

	return shadow / float(sampleCount);
}

// World position reconstruction
vec3 reconstructWorldPos(vec2 screenUV, float depth) {
	vec3 ndc = vec3(screenUV * 2.0 - 1.0, depth * 2.0 - 1.0);
	vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
	viewPos /= viewPos.w;
	vec4 worldPos = gbufferModelViewInverse * viewPos;
	return worldPos.xyz;
}

// Project to shadow space
vec3 projectToShadowSpace(vec3 worldPos) {
	vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
	shadowPos /= shadowPos.w;
	vec2 shadowCoord = shadowPos.xy * 0.5 + 0.5;
	float shadowDepth = shadowPos.z * 0.5 + 0.5;
	shadowCoord = clamp(shadowCoord, vec2(0.0), vec2(1.0));
	return vec3(shadowCoord, shadowDepth);
}

void main() {
	vec4 baseColor = texture(colortex1, uv);
	float depth = texture(depthtex0, uv).r;

	// Sky - no shadow
	if (depth > 0.9999) {
		fragColor = baseColor;
		return;
	}

	// Reconstruct world position and shadow space
	vec3 worldPos = reconstructWorldPos(uv, depth);
	vec3 shadowSpacePos = projectToShadowSpace(worldPos);
	vec2 shadowCoord = shadowSpacePos.xy;
	float shadowDepth = clamp(shadowSpacePos.z, 0.0, 1.0);

	// PCSS
	float lightSize = 0.5;
	float searchRadius = 3.0;

	vec3 blockerInfo = blockerSearch(shadowCoord, shadowDepth, searchRadius);
	if (blockerInfo.y < 0.5) {
		fragColor = baseColor;
		return;
	}

	float penumbra = computePenumbra(blockerInfo.x, shadowDepth, lightSize);
	float shadow = pcfShadow(shadowCoord, shadowDepth, penumbra, 16);

	// Apply shadow
	vec3 shadowColor = baseColor.rgb * (0.4 + shadow * 0.6);
	fragColor = vec4(shadowColor, baseColor.a);
}
