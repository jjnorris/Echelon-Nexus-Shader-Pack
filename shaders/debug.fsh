// ===================================================================
// Echelon Nexus - Debug Visualization Fragment Shader
// ===================================================================
// Visualizes intermediate buffer contents for diagnostics.
// Controlled by DEBUG_VIEW option.
// ===================================================================

#version 330 compatibility

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFORM INPUTS (G-buffer & intermediate results)                         ║
// ╚───────────────────────────────────────────────────────────────────────────╝

uniform sampler2D colortex0;  // Lit scene color
uniform sampler2D colortex1;  // Material parameters (roughness, metallic, emissive)
uniform sampler2D colortex2;  // Normal + depth (oct-encoded)
uniform sampler2D colortex3;  // TAA history
uniform sampler2D colortex4;  // SSR intermediate
uniform sampler2D colortex5;  // Bloom prefilter
uniform int frameCounter;

#include "lib/constants.glsl"
#include "lib/functions.glsl"
#include "lib/pbr_material.glsl"

// ===================================================================
// FRAGMENT INPUT
// ===================================================================

in vec2 vTexCoord;

// ===================================================================
// FRAGMENT OUTPUT
// ===================================================================

out vec4 fragColor;

// ===================================================================
// DEBUG VISUALIZATION MODES
// ===================================================================

// Visualize normal buffer
vec3 visualizeNormals(vec2 texCoord) {
    vec4 normalData = texture(colortex2, texCoord);

    // Decode normal from oct-wrap
    vec2 encodedNormal = normalData.xy;
    vec3 normal = decodeUnitVector(encodedNormal);

    // Convert to color space: N*0.5 + 0.5
    return normal * 0.5 + 0.5;
}

// Visualize roughness
vec3 visualizeRoughness(vec2 texCoord) {
    vec4 materialData = texture(colortex1, texCoord);
    float roughness = materialData.r;
    return vec3(roughness);
}

// Visualize metallic
vec3 visualizeMetallic(vec2 texCoord) {
    vec4 materialData = texture(colortex1, texCoord);
    float metallic = materialData.g;
    return vec3(metallic);
}

// Visualize emissive
vec3 visualizeEmissive(vec2 texCoord) {
    vec4 materialData = texture(colortex1, texCoord);
    float emissive = materialData.b;
    return vec3(emissive);
}

// Visualize depth (linear, remapped to [0, 1])
vec3 visualizeDepth(vec2 texCoord) {
    vec4 normalData = texture(colortex2, texCoord);
    float depth = normalData.b;

    // Remap depth to visible range (0.0-0.3 = black, 0.3-1.0 = gradient)
    float remapped = smoothstep(0.0, 0.5, depth);
    return vec3(remapped);
}

// Visualize scene lighting (direct lighting contribution)
vec3 visualizeLighting(vec2 texCoord) {
    // If lighting is in colortex0, visualize directly
    // For now, show the lit scene color
    vec3 sceneColor = texture(colortex0, texCoord).rgb;
    return sceneColor;
}

// Visualize TAA history (colortex3)
vec3 visualizeHistory(vec2 texCoord) {
    vec4 historyData = texture(colortex3, texCoord);
    vec3 historyColor = historyData.rgb;

    // Visualize as-is (will show temporal flickering if TAA is active)
    return historyColor;
}

// Visualize SSR (colortex4, half-res)
vec3 visualizeSSR(vec2 texCoord) {
    // SSR is half-res; scale texture coordinates
    vec2 halfResCoord = texCoord * 0.5;
    vec4 ssrData = texture(colortex4, halfResCoord);

    vec3 reflectionColor = ssrData.rgb;
    float confidence = ssrData.a;

    // Tint with confidence
    vec3 display = mix(vec3(0.2, 0.2, 0.5), reflectionColor, confidence);
    return display;
}

// Visualize bloom prefilter (colortex5, quarter-res)
vec3 visualizeBloom(vec2 texCoord) {
    // Bloom is quarter-res
    vec2 quarterResCoord = texCoord * 0.25;
    vec4 bloomData = texture(colortex5, quarterResCoord);

    return bloomData.rgb * 2.0;  // Amplify for visibility
}

// Visualize raw colortex0 (scene color)
vec3 visualizeSceneColor(vec2 texCoord) {
    return texture(colortex0, texCoord).rgb;
}

// Visualize checkerboard pattern (for null debug)
vec3 visualizeCheckerboard(vec2 texCoord) {
    vec2 checker = floor(texCoord * 16.0);
    float isWhite = mod(checker.x + checker.y, 2.0);
    return vec3(isWhite);
}

// ===================================================================
// MAIN DEBUG VISUALIZATION
// ===================================================================

void main() {
    vec3 debugColor = vec3(0.0);

    // Note: DEBUG_VIEW option will be set via shaders.properties
    // For now, we'll use a placeholder and cycle through visualizations

    // Simple animation: cycle through debug modes every second
    float time = mod(float(frameCounter) * 0.016, 8.0);  // ~60 FPS, cycle every 8 frames
    int debugMode = int(time);

    switch (debugMode) {
        case DEBUG_NORMALS:
            debugColor = visualizeNormals(vTexCoord);
            break;
        case DEBUG_ROUGHNESS:
            debugColor = visualizeRoughness(vTexCoord);
            break;
        case DEBUG_METALLIC:
            debugColor = visualizeMetallic(vTexCoord);
            break;
        case DEBUG_EMISSIVE:
            debugColor = visualizeEmissive(vTexCoord);
            break;
        case DEBUG_DEPTH:
            debugColor = visualizeDepth(vTexCoord);
            break;
        case DEBUG_LIGHTING:
            debugColor = visualizeLighting(vTexCoord);
            break;
        case DEBUG_HISTORY:
            debugColor = visualizeHistory(vTexCoord);
            break;
        case DEBUG_SSR:
            debugColor = visualizeSSR(vTexCoord);
            break;
        default:
            debugColor = visualizeCheckerboard(vTexCoord);
    }

    fragColor = vec4(debugColor, 1.0);
}

// ===================================================================
// END OF DEBUG VISUALIZATION SHADER
// ===================================================================
