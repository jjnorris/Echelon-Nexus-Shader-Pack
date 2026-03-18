// ===================================================================
// Echelon Nexus Shader Pack - Shared Utility Functions
// ===================================================================

#ifndef INCLUDE_FUNCTIONS
#define INCLUDE_FUNCTIONS

#include "constants.glsl"

// ===================================================================
// BASIC MATH UTILITIES
// ===================================================================

// Safe reciprocal (avoid division by zero)
float safeReciprocal(float x) {
    return (abs(x) > EPSILON) ? 1.0 / x : 0.0;
}

// Smooth step with derivatives
float smoothstepSmooth(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// Mix with a smoother curve
vec3 mixSmooth(vec3 a, vec3 b, float t) {
    t = smoothstep(0.0, 1.0, t);
    return mix(a, b, t);
}

// Linear interpolation with clamping
float lerp(float a, float b, float t) {
    return a + (b - a) * clamp(t, 0.0, 1.0);
}

vec3 lerp(vec3 a, vec3 b, float t) {
    return a + (b - a) * clamp(t, 0.0, 1.0);
}

// ===================================================================
// TRIGONOMETRIC & ANGLE UTILITIES
// ===================================================================

// Fast sine approximation (Minimax, good for animation)
float fastSin(float x) {
    x = fract(x * INV_TWO_PI);
    float x2 = x * x;
    if (x < 0.5) {
        return 4.0 * x * (1.0 - x);
    } else {
        x = x - 1.0;
        return 4.0 * x * (1.0 - x);
    }
}

// Fast cosine (via sine phase shift)
float fastCos(float x) {
    return fastSin(x + HALF_PI);
}

// ===================================================================
// COLOR SPACE CONVERSIONS
// ===================================================================

// sRGB to linear RGB
vec3 srgbToLinear(vec3 c) {
    return pow(c, vec3(SRGB_GAMMA));
}

// Linear RGB to sRGB
vec3 linearToSrgb(vec3 c) {
    return pow(c, vec3(SRGB_INV_GAMMA));
}

// Single channel sRGB to linear
float srgbToLinear(float c) {
    return pow(c, SRGB_GAMMA);
}

// Single channel linear to sRGB
float linearToSrgb(float c) {
    return pow(c, SRGB_INV_GAMMA);
}

// ===================================================================
// LUMINANCE & BRIGHTNESS UTILITIES
// ===================================================================

// Compute luminance using ITU-R BT.709 (standard modern)
float luminance(vec3 color) {
    return dot(color, LUMA_BT709);
}

// Compute relative luminance (for WCAG contrast calculations)
float relativeLuminance(vec3 c) {
    c = srgbToLinear(c);
    return dot(c, LUMA_BT709);
}

// Perceived brightness (more perceptually uniform)
float perceivedBrightness(vec3 color) {
    return dot(color, LUMA_PERCEIVED);
}

// Get the dominant color channel
int getDominantChannel(vec3 c) {
    if (c.r > c.g && c.r > c.b) return 0;
    if (c.g > c.r && c.g > c.b) return 1;
    return 2;
}

// ===================================================================
// VECTOR UTILITIES
// ===================================================================

// Normalize with epsilon protection
vec3 safeNormalize(vec3 v) {
    float len = length(v);
    return (len > EPSILON) ? v / len : vec3(0.0);
}

// 2D version
vec2 safeNormalize(vec2 v) {
    float len = length(v);
    return (len > EPSILON) ? v / len : vec2(0.0);
}

// Reflect vector across normal
vec3 reflectVector(vec3 incident, vec3 normal) {
    return incident - 2.0 * dot(incident, normal) * normal;
}

// Refract vector (simplified; assumes normal is already normalized)
vec3 refractVector(vec3 incident, vec3 normal, float etaRatio) {
    float cosI = -dot(incident, normal);
    float sinT2 = etaRatio * etaRatio * (1.0 - cosI * cosI);

    if (sinT2 > 1.0) {
        return reflectVector(incident, normal);  // Total internal reflection
    }

    float cosT = sqrt(1.0 - sinT2);
    return etaRatio * incident + (etaRatio * cosI - cosT) * normal;
}

// ===================================================================
// PACKING & ENCODING UTILITIES
// ===================================================================

// Pack two floats into a single float (10-bit + 10-bit precision)
// Useful for storing two unit-range values compactly
float packFloat10(float a, float b) {
    a = clamp(a, 0.0, 1.0);
    b = clamp(b, 0.0, 1.0);
    return (floor(a * 1023.0) + floor(b * 1023.0) * 1024.0) / (1024.0 * 1024.0 - 1.0);
}

// Unpack two floats from a single packed float
void unpackFloat10(float packed, out float a, out float b) {
    float combined = packed * (1024.0 * 1024.0 - 1.0);
    a = fract(combined / 1024.0);
    b = floor(combined / 1024.0) / 1023.0;
}

// Encode unit vector to two components (oct-wrap)
vec2 encodeUnitVector(vec3 v) {
    float l1norm = abs(v.x) + abs(v.y) + abs(v.z);
    vec2 uv = v.xy / l1norm;

    if (v.z < 0.0) {
        float oldU = uv.x;
        uv.x = (1.0 - abs(uv.y)) * (oldU >= 0.0 ? 1.0 : -1.0);
        uv.y = (1.0 - abs(oldU)) * (uv.y >= 0.0 ? 1.0 : -1.0);
    }

    return uv * 0.5 + 0.5;
}

// Decode unit vector from two components (oct-wrap)
vec3 decodeUnitVector(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec3 v = vec3(uv.x, uv.y, 1.0 - abs(uv.x) - abs(uv.y));

    if (v.z < 0.0) {
        float oldX = v.x;
        v.x = (1.0 - abs(v.y)) * (oldX >= 0.0 ? 1.0 : -1.0);
        v.y = (1.0 - abs(oldX)) * (v.y >= 0.0 ? 1.0 : -1.0);
    }

    return normalize(v);
}

// ===================================================================
// DEPTH UTILITIES
// ===================================================================

// Linearize depth from OpenGL depth (assumes standard projection)
// depthndc should be in range [0, 1]
float linearizeDepth(float depthndc, float near, float far) {
    float depthNDC = 2.0 * depthndc - 1.0;  // Convert from [0,1] to [-1,1]
    float depthView = 2.0 * near * far / (far + near - depthNDC * (far - near));
    return depthView;
}

// Convert linear depth back to NDC
float depthToNDC(float depthLinear, float near, float far) {
    float depthNDC = (far + near - 2.0 * near * far / depthLinear) / (far - near);
    return (depthNDC + 1.0) * 0.5;  // Convert from [-1,1] to [0,1]
}

// ===================================================================
// NOISE UTILITIES (Basic)
// ===================================================================

// Pseudo-random number from a 1D seed
float rand(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

// Pseudo-random number from a 2D seed
float rand(vec2 seed) {
    return fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
}

// Pseudo-random number from a 3D seed
float rand(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

// ===================================================================
// DISTRIBUTION UTILITIES
// ===================================================================

// Clamp with smoothness at edges (avoid harsh discontinuities)
float smoothClamp(float x, float lo, float hi, float smoothWidth) {
    float s = smoothstep(lo - smoothWidth, lo, x) - smoothstep(hi, hi + smoothWidth, x);
    return mix(x, clamp(x, lo, hi), s);
}

// Map a value from one range to another
float remap(float value, float oldMin, float oldMax, float newMin, float newMax) {
    float normalized = (value - oldMin) / (oldMax - oldMin);
    return newMin + normalized * (newMax - newMin);
}

// ===================================================================
// SCREEN SPACE UTILITIES
// ===================================================================

// Reconstruct view position from depth (requires inverse projection matrix)
vec3 reconstructViewPos(vec2 texcoord, float depth, mat4 projInv) {
    vec4 clipPos = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = projInv * clipPos;
    return viewPos.xyz / viewPos.w;
}

// Reconstruct world position from screen position
// Requires viewPos and the inverse view matrix
vec3 reconstructWorldPos(vec3 viewPos, mat4 viewInv) {
    vec4 worldPos = viewInv * vec4(viewPos, 1.0);
    return worldPos.xyz;
}

// Compute screen-space derivatives
vec3 screenSpaceDerivatives(sampler2D tex, vec2 texcoord, vec2 invResolution) {
    float ddx = textureOffset(tex, texcoord, ivec2(1, 0)).x - textureOffset(tex, texcoord, ivec2(-1, 0)).x;
    float ddy = textureOffset(tex, texcoord, ivec2(0, 1)).x - textureOffset(tex, texcoord, ivec2(0, -1)).x;
    return vec3(ddx * invResolution.x, ddy * invResolution.y, 0.0);
}

// ===================================================================
// MISCELLANEOUS UTILITIES
// ===================================================================

// Check if a value is NaN
bool isNaN(float x) {
    return x != x;
}

// Clamp color to valid range [0, 1]
vec3 clampColor(vec3 c) {
    return clamp(c, 0.0, 1.0);
}

// Clamp and warn (in debug mode)
vec3 clampColorSafe(vec3 c) {
    return clamp(c, 0.0, 1.0);
}

// ===================================================================
// END OF FUNCTIONS
// ===================================================================

#endif // INCLUDE_FUNCTIONS
