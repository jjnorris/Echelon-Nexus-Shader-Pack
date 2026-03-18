// ===================================================================
// Echelon Nexus - Viewport & Depth Reconstruction Utilities
// ===================================================================
// Reconstructs world and view positions from depth for deferred effects.
// ===================================================================

#ifndef INCLUDE_VIEWPORT
#define INCLUDE_VIEWPORT

#include "constants.glsl"
#include "functions.glsl"

// ===================================================================
// VIEW/PROJECTION MATRIX INVERSE
// ===================================================================

// These should be provided by Iris automatically
// uniform mat4 gbufferProjectionInverse;
// uniform mat4 gbufferModelViewInverse;
// uniform vec3 cameraPosition;
// uniform mat4 gbufferProjection;
// uniform mat4 gbufferModelView;

// ===================================================================
// DEPTH RECONSTRUCTION
// ===================================================================

// Convert normalized device coordinate depth to linear view space depth
float ndcDepthToViewDepth(float ndcDepth, float near, float far) {
    float z_ndc = 2.0 * ndcDepth - 1.0;
    return 2.0 * near * far / (far + near - z_ndc * (far - near));
}

// More accurate: use projection matrix for proper linearization
float linearizeDepthWithMatrix(float ndcDepth, mat4 projection) {
    float z = 2.0 * ndcDepth - 1.0;
    return 2.0 * projection[3][2] / (z * (projection[2][2] - 1.0) - projection[2][2]);
}

// ===================================================================
// VIEW SPACE POSITION RECONSTRUCTION
// ===================================================================

// Reconstruct view-space position from screen coordinates and depth
vec3 reconstructViewPos(vec2 screenCoord, float depth, mat4 projectionInv) {
    // Convert screen coordinates to NDC [-1, 1]
    vec4 ndc = vec4(screenCoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);

    // Transform from NDC to view space using inverse projection
    vec4 viewPos = projectionInv * ndc;

    // Divide by w to get actual view position
    return viewPos.xyz / viewPos.w;
}

// ===================================================================
// WORLD SPACE POSITION RECONSTRUCTION
// ===================================================================

// Reconstruct world-space position from view position and inverse view matrix
vec3 reconstructWorldPos(vec3 viewPos, mat4 viewInv) {
    return (viewInv * vec4(viewPos, 1.0)).xyz;
}

// Combined: screen coords + depth → world position
vec3 reconstructWorldPosFromScreen(
    vec2 screenCoord,
    float depth,
    mat4 projectionInv,
    mat4 viewInv,
    vec3 cameraPos
) {
    vec3 viewPos = reconstructViewPos(screenCoord, depth, projectionInv);
    return reconstructWorldPos(viewPos, viewInv) + cameraPos;
}

// ===================================================================
// VIEW DIRECTION COMPUTATION
// ===================================================================

// Compute view direction from fragment to camera (normalized)
vec3 computeViewDir(vec3 fragmentWorldPos, vec3 cameraWorldPos) {
    return normalize(cameraWorldPos - fragmentWorldPos);
}

// Quick view direction (approximation when exact position not available)
vec3 approximateViewDir(vec2 screenCoord, mat4 projectionInv) {
    // Ray direction from camera through screen pixel
    vec4 ndc = vec4(screenCoord * 2.0 - 1.0, 1.0, 1.0);
    vec4 viewRay = projectionInv * ndc;
    return normalize(viewRay.xyz);
}

// ===================================================================
// NORMAL VALIDATION & PROCESSING
// ===================================================================

// Check if a normal is front-facing relative to view direction
bool isFrontFacing(vec3 normal, vec3 viewDir) {
    return dot(normal, viewDir) > 0.0;
}

// Flip normal if backfacing
vec3 ensureFrontFacing(vec3 normal, vec3 viewDir) {
    return isFrontFacing(normal, viewDir) ? normal : -normal;
}

// ===================================================================
// SCREEN SPACE DERIVATIVES
// ===================================================================

// Compute finite difference derivatives for screen-space effects
vec3 getScreenSpaceDerivativeX(sampler2D tex, vec2 texCoord, vec2 invResolution) {
    vec3 left = texture(tex, texCoord - vec2(invResolution.x, 0.0)).rgb;
    vec3 right = texture(tex, texCoord + vec2(invResolution.x, 0.0)).rgb;
    return (right - left) * 0.5;
}

vec3 getScreenSpaceDerivativeY(sampler2D tex, vec2 texCoord, vec2 invResolution) {
    vec3 top = texture(tex, texCoord - vec2(0.0, invResolution.y)).rgb;
    vec3 bottom = texture(tex, texCoord + vec2(0.0, invResolution.y)).rgb;
    return (bottom - top) * 0.5;
}

// ===================================================================
// EDGE DETECTION
// ===================================================================

// Simple depth discontinuity detection for anti-aliasing
float detectDepthEdge(vec2 texCoord, vec2 invResolution) {
    float centerDepth = texture(depthtex0, texCoord).r;

    float leftDepth = texture(depthtex0, texCoord - vec2(invResolution.x, 0.0)).r;
    float rightDepth = texture(depthtex0, texCoord + vec2(invResolution.x, 0.0)).r;
    float topDepth = texture(depthtex0, texCoord - vec2(0.0, invResolution.y)).r;
    float bottomDepth = texture(depthtex0, texCoord + vec2(0.0, invResolution.y)).r;

    float dx = max(abs(centerDepth - leftDepth), abs(centerDepth - rightDepth));
    float dy = max(abs(centerDepth - topDepth), abs(centerDepth - bottomDepth));

    return max(dx, dy);
}

// Normal discontinuity detection
float detectNormalEdge(vec2 texCoord, vec2 invResolution) {
    vec2 encodedNormalCenter = texture(colortex2, texCoord).xy;
    vec3 normalCenter = decodeUnitVector(encodedNormalCenter);

    vec2 encodedNormalLeft = texture(colortex2, texCoord - vec2(invResolution.x, 0.0)).xy;
    vec3 normalLeft = decodeUnitVector(encodedNormalLeft);

    vec2 encodedNormalRight = texture(colortex2, texCoord + vec2(invResolution.x, 0.0)).xy;
    vec3 normalRight = decodeUnitVector(encodedNormalRight);

    float edgeX = 1.0 - dot(normalCenter, normalLeft);
    edgeX = max(edgeX, 1.0 - dot(normalCenter, normalRight));

    vec2 encodedNormalTop = texture(colortex2, texCoord - vec2(0.0, invResolution.y)).xy;
    vec3 normalTop = decodeUnitVector(encodedNormalTop);

    vec2 encodedNormalBottom = texture(colortex2, texCoord + vec2(0.0, invResolution.y)).xy;
    vec3 normalBottom = decodeUnitVector(encodedNormalBottom);

    float edgeY = 1.0 - dot(normalCenter, normalTop);
    edgeY = max(edgeY, 1.0 - dot(normalCenter, normalBottom));

    return max(edgeX, edgeY);
}

// ===================================================================
// TANGENT SPACE UTILITIES
// ===================================================================

// Build orthonormal basis from surface normal
void buildTangentBasis(
    vec3 normal,
    vec3 tangent,
    out vec3 outNormal,
    out vec3 outTangent,
    out vec3 outBitangent
) {
    outNormal = normalize(normal);

    if (abs(outNormal.z) < 0.9) {
        outTangent = normalize(cross(vec3(0.0, 0.0, 1.0), outNormal));
    } else {
        outTangent = normalize(cross(vec3(0.0, 1.0, 0.0), outNormal));
    }

    outBitangent = cross(outNormal, outTangent);
}

// Transform vector from tangent space to world space
vec3 tangentToWorldSpace(vec3 tangentVec, vec3 normal, vec3 tangent, vec3 bitangent) {
    return tangentVec.x * tangent + tangentVec.y * bitangent + tangentVec.z * normal;
}

// ===================================================================
// END OF VIEWPORT MODULE
// ===================================================================

#endif // INCLUDE_VIEWPORT
