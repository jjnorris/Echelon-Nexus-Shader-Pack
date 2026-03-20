// ============================================================================
// MATH LIBRARY
// Utility Functions for Shader Calculations
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Common shader math patterns
//
// Purpose: Reusable math functions for common calculations

#ifndef INCLUDED_MATH
#define INCLUDED_MATH

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;
const float INV_PI = 0.31830988618;
const float SQRT_2 = 1.41421356237;

// ============================================================================
// CONVERSION FUNCTIONS
// ============================================================================

float linearToSRGB(float linear) {
	if (linear <= 0.0031308) {
		return 12.92 * linear;
	} else {
		return (1.055 * pow(linear, 1.0 / 2.4)) - 0.055;
	}
}

vec3 linearToSRGB(vec3 linear) {
	return vec3(
		linearToSRGB(linear.r),
		linearToSRGB(linear.g),
		linearToSRGB(linear.b)
	);
}

float sRGBToLinear(float srgb) {
	if (srgb <= 0.04045) {
		return srgb / 12.92;
	} else {
		return pow((srgb + 0.055) / 1.055, 2.4);
	}
}

vec3 sRGBToLinear(vec3 srgb) {
	return vec3(
		sRGBToLinear(srgb.r),
		sRGBToLinear(srgb.g),
		sRGBToLinear(srgb.b)
	);
}

// ============================================================================
// INTERPOLATION & SMOOTHING
// ============================================================================

// Smooth step using cubic interpolation
float smoothstepCubic(float edge0, float edge1, float x) {
	float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// Smooth step using quintic interpolation (smoother)
float smoothstepQuintic(float edge0, float edge1, float x) {
	float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// ============================================================================
// GEOMETRY & VECTORS
// ============================================================================

// Calculate tangent from normal
vec3 calculateTangent(vec3 normal) {
	vec3 tangent = abs(normal.z) < 0.9 ?
		vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	return normalize(cross(normal, tangent));
}

// Calculate bitangent from normal and tangent
vec3 calculateBitangent(vec3 normal, vec3 tangent) {
	return normalize(cross(normal, tangent));
}

// Rotate vector around axis
vec3 rotateAroundAxis(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);

	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// ============================================================================
// COLOR FUNCTIONS
// ============================================================================

// Luminance (perceived brightness)
float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

// RGB to HSL conversion
vec3 rgbToHsl(vec3 rgb) {
	float maxC = max(max(rgb.r, rgb.g), rgb.b);
	float minC = min(min(rgb.r, rgb.g), rgb.b);
	float l = (maxC + minC) / 2.0;

	float h = 0.0;
	float s = 0.0;

	if (maxC != minC) {
		float d = maxC - minC;
		s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);

		if (maxC == rgb.r) {
			h = (rgb.g - rgb.b) / d + (rgb.g < rgb.b ? 6.0 : 0.0);
		} else if (maxC == rgb.g) {
			h = (rgb.b - rgb.r) / d + 2.0;
		} else {
			h = (rgb.r - rgb.g) / d + 4.0;
		}
		h /= 6.0;
	}

	return vec3(h, s, l);
}

float hue2rgb(float p, float q, float t) {
	if (t < 0.0) t += 1.0;
	if (t > 1.0) t -= 1.0;
	if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
	if (t < 1.0 / 2.0) return q;
	if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
	return p;
}

// HSL to RGB conversion
vec3 hslToRgb(vec3 hsl) {
	vec3 rgb;

	if (hsl.y == 0.0) {
		rgb = vec3(hsl.z);
	} else {
		float q = hsl.z < 0.5 ?
			hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
		float p = 2.0 * hsl.z - q;

		rgb.r = hue2rgb(p, q, hsl.x + 1.0 / 3.0);
		rgb.g = hue2rgb(p, q, hsl.x);
		rgb.b = hue2rgb(p, q, hsl.x - 1.0 / 3.0);
	}

	return rgb;
}

// ============================================================================
// PACKING & UNPACKING
// ============================================================================

// Pack normal to 2 channels
vec2 packNormal(vec3 normal) {
	return normalize(normal.xy) * sqrt(0.5 * (1.0 - normal.z));
}

// Unpack normal from 2 channels
vec3 unpackNormal(vec2 packed) {
	vec3 n;
	n.xy = packed * 2.0 - 1.0;
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	return n;
}

// Pack 4 floats into 1 float (lossy, for debugging)
float packFloat(vec4 value) {
	return dot(value, vec4(1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0));
}

#endif
