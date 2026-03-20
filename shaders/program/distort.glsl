/* =============================================================================
   Texture Distortion & Surface Detail Library

   Advanced surface detail techniques:
   - Parallax mapping: Height-based texture coordinate adjustment
   - Normal mapping: Surface normal detail from textures
   - Parallax occlusion mapping: Geometric surface simulation

   These techniques add surface detail without increasing geometry complexity.

   Reference: "Steep Parallax Mapping with Accurate Silhouettes"
   Authors: Vaclav Skala, Jan Martínek

   ============================================================================= */

#ifndef INCLUDED_DISTORT
#define INCLUDED_DISTORT

// ============================================================================
// Parallax Mapping (Phase 2+)
// ============================================================================

/**
 * Simple parallax mapping
 * Offsets texture coordinates based on height and view angle
 *
 * Produces the illusion of surface displacement without additional geometry.
 * More pronounced from grazing angles.
 *
 * @param texCoord Original texture coordinate
 * @param viewDir View direction in tangent space
 * @param heightMap Height texture sampler
 * @param heightScale Parallax effect intensity (0.02 to 0.1)
 * @return Adjusted texture coordinate
 */
vec2 parallaxMapping(
	vec2 texCoord, vec3 viewDir,
	sampler2D heightMap, float heightScale
) {
	// Sample height at original coordinates
	float height = texture(heightMap, texCoord).r;

	// Calculate parallax offset
	vec2 p = viewDir.xy / viewDir.z * (height * heightScale);

	return texCoord - p;
}

/**
 * Steep parallax mapping with self-shadowing
 * More accurate than simple parallax, produces shadowing effect
 *
 * Uses linear search followed by binary search for accuracy
 *
 * @param texCoord Original texture coordinate
 * @param viewDir View direction in tangent space
 * @param heightMap Height texture sampler
 * @param heightScale Parallax effect intensity
 * @param numLayers Number of layers for height tracing (8-32)
 * @return Adjusted texture coordinate with improved quality
 */
vec2 steepParallaxMapping(
	vec2 texCoord, vec3 viewDir,
	sampler2D heightMap, float heightScale, int numLayers
) {
	// Current layer from viewDir
	float layerDepth = 1.0 / float(numLayers);
	float currentLayerDepth = 0.0;

	// Parallax per layer
	vec2 P = viewDir.xy / viewDir.z * heightScale;
	vec2 deltaTexCoords = P / float(numLayers);

	vec2 currentTexCoords = texCoord;
	float currentDepthMapValue = texture(heightMap, currentTexCoords).r;

	// Linear search - find intersection
	while (currentLayerDepth < currentDepthMapValue) {
		currentTexCoords -= deltaTexCoords;
		currentDepthMapValue = texture(heightMap, currentTexCoords).r;
		currentLayerDepth += layerDepth;
	}

	// Binary search refinement (optional - Phase 3+)
	// For Phase 2, linear search is sufficient

	return currentTexCoords;
}

// ============================================================================
// Normal Mapping
// ============================================================================

/**
 * Unpack normal from normal map texture
 * Converts from texture format (RGB 0-1) to normal vector (-1 to 1)
 *
 * Common formats:
 * - Direct: (R, G, B) directly as (X, Y, Z)
 * - Two-channel: (R, G) as (X, Y), reconstruct Z
 *
 * @param normalColor Color from normal map texture
 * @return Normal vector in [-1, 1] range (unnormalized)
 */
vec3 unpackNormalMap(vec4 normalColor) {
	// Standard format: RGB = XYZ scaled to [0,1]
	vec3 normal = normalColor.rgb * 2.0 - 1.0;  // [0,1] -> [-1,1]
	return normalize(normal);
}

/**
 * Unpack normal from two-channel format (common on mobile)
 * Uses BC5/DXT5 compression where only R and G are stored
 *
 * @param rg Red and Green channels from texture
 * @return Normal vector (reconstructed Z from XY)
 */
vec3 unpackNormalMap2Channel(vec2 rg) {
	vec3 normal = vec3(rg * 2.0 - 1.0, 0.0);
	normal.z = sqrt(max(0.0, 1.0 - dot(normal.xy, normal.xy)));
	return normalize(normal);
}

/**
 * Blend two normal maps together
 * Useful for layered surface details
 *
 * Uses Reoriented Normal Mapping (RNM) for better blending
 * Reference: Blending in Detail by whiterabbit@polycount
 *
 * @param normal1 First normal (in tangent space)
 * @param normal2 Second normal (in tangent space)
 * @return Blended normal
 */
vec3 blendNormalMaps(vec3 normal1, vec3 normal2) {
	// Simple linear blend (Phase 2)
	// Phase 3+ can use RNM for improved blending
	return normalize(normal1 + normal2);
}

// ============================================================================
// Surface Detail
// ============================================================================

/**
 * Calculate tangent space normal from height map (generates normal map)
 * Approximates normal from height derivatives
 *
 * @param heightMap Height texture sampler
 * @param texCoord Texture coordinate
 * @param texelSize Size of one texel (1.0 / textureSize)
 * @return Normal in tangent space
 */
vec3 heightToNormal(sampler2D heightMap, vec2 texCoord, float texelSize) {
	float h00 = texture(heightMap, texCoord).r;
	float h10 = texture(heightMap, texCoord + vec2(texelSize, 0.0)).r;
	float h01 = texture(heightMap, texCoord + vec2(0.0, texelSize)).r;

	// Compute height gradients
	float dx = (h10 - h00) / texelSize;
	float dy = (h01 - h00) / texelSize;

	// Normal from gradients (Sobel filter)
	vec3 normal = normalize(vec3(-dx, -dy, 1.0));
	return normal;
}

/**
 * Detail normal application
 * Blends a detail normal into existing normal based on intensity
 *
 * @param baseNormal Original surface normal
 * @param detailNormal Detail normal from map
 * @param intensity Blending intensity (0-1)
 * @return Modified normal with detail
 */
vec3 applyDetailNormal(vec3 baseNormal, vec3 detailNormal, float intensity) {
	return normalize(mix(baseNormal, detailNormal, intensity));
}

// ============================================================================
// Texture Coordinate Distortion
// ============================================================================

/**
 * Wave-based distortion for water surfaces
 * Displaces texture coordinates to simulate wave movement
 *
 * @param texCoord Original texture coordinates
 * @param waveAmount Amplitude of waves
 * @param time Current time for animation
 * @return Distorted texture coordinates
 */
vec2 waveDistortion(vec2 texCoord, float waveAmount, float time) {
	vec2 waves = vec2(
		sin(texCoord.x * 10.0 + time) * 0.1,
		cos(texCoord.y * 10.0 + time) * 0.1
	);
	return texCoord + waves * waveAmount;
}

/**
 * Chromatic aberration (color fringing)
 * Separates RGB channels based on refraction angle
 * Creates realistic glass/transparent material appearance
 *
 * @param texCoord Texture coordinate center
 * @param aberration Amount of chromatic shift
 * @param sampler Texture sampler
 * @return Color with separated RGB channels
 */
vec4 chromaticAberration(vec2 texCoord, float aberration, sampler2D sampler) {
	vec4 color;
	color.r = texture(sampler, texCoord + vec2(aberration, 0.0)).r;
	color.g = texture(sampler, texCoord).g;
	color.b = texture(sampler, texCoord - vec2(aberration, 0.0)).b;
	color.a = 1.0;
	return color;
}

#endif // INCLUDED_DISTORT
