/* =============================================================================
   Math Utilities Library

   Common mathematical functions for shader operations:
   - Vector operations (normalize, dot, cross)
   - Matrix operations (transforms)
   - Trigonometric and utility functions
   - Packed value encoding/decoding

   These utilities provide numerical stability and consistency across
   shader programs.

   ============================================================================= */

#ifndef INCLUDED_MATH
#define INCLUDED_MATH

// ============================================================================
// Vector Operations
// ============================================================================

/**
 * Safe normalization with epsilon to prevent division by zero
 *
 * @param v Vector to normalize
 * @return Normalized vector (or zero vector if too small)
 */
vec3 safeNormalize(vec3 v) {
	float len = length(v);
	return len > 1e-5 ? v / len : vec3(0.0);
}

/**
 * Reflect vector around surface normal
 *
 * @param incident Incoming direction (toward surface)
 * @param normal Surface normal
 * @return Reflected direction
 */
vec3 reflectVector(vec3 incident, vec3 normal) {
	return incident - 2.0 * dot(incident, normal) * normal;
}

// ============================================================================
// Angle Calculations
// ============================================================================

/**
 * Clamp dot product to safe range [0, 1]
 * Prevents negative cosines from invalid normal directions
 */
float safeDot(vec3 a, vec3 b) {
	return max(0.0, dot(a, b));
}

/**
 * Half vector between view and light directions
 * Used in BRDF calculations for Fresnel and microfacet distribution
 */
vec3 halfVector(vec3 viewDir, vec3 lightDir) {
	return normalize(viewDir + lightDir);
}

// ============================================================================
// Color Space Conversions
// ============================================================================

/**
 * Linear to sRGB gamma correction
 * Converts from linear color space (for calculations) to sRGB (for display)
 *
 * Reference: IEC 61966-2-1:1999
 *
 * @param linear Linear color value (0-1 range)
 * @return sRGB color value (0-1 range)
 */
vec3 linearToSRGB(vec3 linear) {
	// Approximation: pow(linear, 1.0/2.2)
	// Exact formula includes threshold at 0.0031308
	return pow(max(linear, vec3(0.0)), vec3(1.0 / 2.2));
}

/**
 * sRGB to Linear gamma correction
 * Converts from display color space to linear for calculations
 */
vec3 sRGBToLinear(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

// ============================================================================
// Packing/Unpacking
// ============================================================================

/**
 * Pack two floats (0-1) into a single vec2 for storage
 * Useful for normal map compression: encode normal XY in vec2
 */
vec2 packFloat16(float a, float b) {
	return vec2(a, b);
}

/**
 * Unpack two floats from a vec2
 */
void unpackFloat16(vec2 packed, out float a, out float b) {
	a = packed.x;
	b = packed.y;
}

/**
 * Pack normal vector (3D) into vec2 (octahedron encoding)
 * Reduces storage from 3 floats to 2 with minimal quality loss
 *
 * @param normal 3D unit normal vector
 * @return Packed normal in vec2
 */
vec2 packNormal(vec3 normal) {
	// Simple 2-component packing: XY only
	// Phase 2+ can use octahedron encoding for better quality
	return normal.xy;
}

/**
 * Unpack normal vector from vec2
 * Reconstructs Z from XY assuming unit length
 */
vec3 unpackNormal(vec2 packed) {
	vec3 normal = vec3(packed.xy, 0.0);
	normal.z = sqrt(max(0.0, 1.0 - dot(normal.xy, normal.xy)));
	return normalize(normal);
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Linear interpolation (lerp)
 * Blends between two values based on factor t
 */
vec3 mix3(vec3 a, vec3 b, float t) {
	return mix(a, b, t);
}

/**
 * Smoothstep function - smooth interpolation
 * Used for soft transitions and falloff curves
 */
float smoothstep(float edge0, float edge1, float x) {
	float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t); // Hermite interpolation
}

/**
 * Remap value from one range to another
 * @param value Input value
 * @param inMin Input range minimum
 * @param inMax Input range maximum
 * @param outMin Output range minimum
 * @param outMax Output range maximum
 */
float remap(float value, float inMin, float inMax, float outMin, float outMax) {
	float t = (value - inMin) / (inMax - inMin);
	return mix(outMin, outMax, clamp(t, 0.0, 1.0));
}

/**
 * Luminance calculation (sRGB)
 * Perceptual brightness of a color
 * Reference: ITU-R BT.709
 */
float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

#endif // INCLUDED_MATH
