#version 130
precision highp float;
// Low-quality composite preset (PCSS: blocker=8, PCF cap=16) - for weaker GPUs

// Samplers for input textures
uniform sampler2D colortex0;    // Base color from gbuffers
uniform sampler2D depthtex0;    // Scene depth buffer
uniform sampler2D shadowtex0;   // Shadow map (directional light)
uniform sampler2D shadowcolor0; // Colored shadow data

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform int debugMode; // 0=off,1=depth,2=worldPos,3=shadowCoord,4=shadow value
int shadowDepthInvert = 1;
float shadowBias = 0.002;

in vec2 uv;
out vec4 fragColor;

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

// Preset caps
const int PCSS_BLOCKER_SAMPLES = 8;
const int PCSS_PCF_SAMPLES_CAP = 16;

vec3 pcssBlockerSearch(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                       float searchRadius, int sampleCount) {
    float avgBlockerDepth = 0.0;
    float blockerCount = 0.0;

    for (int i = 0; i < 16; i++) {
        if (i >= sampleCount) break;

        vec2 offset = poissonDisk16[i] * searchRadius;
        vec2 samplePos = sampleCoord + offset;
        samplePos = clamp(samplePos, vec2(0.0), vec2(1.0));

        float sampledDepth = texture(shadowMap, samplePos).x;
        if (shadowDepthInvert == 1) sampledDepth = 1.0 - sampledDepth;
        if (sampledDepth + shadowBias < receiverDepth) {
            avgBlockerDepth += sampledDepth;
            blockerCount += 1.0;
        }
    }

    if (blockerCount > 0.0) {
        avgBlockerDepth /= blockerCount;
    } else {
        avgBlockerDepth = 0.0;
        blockerCount = 0.0;
    }

    return vec3(avgBlockerDepth, blockerCount, searchRadius);
}

float pcssComputePenumbra(float avgBlockerDepth, float receiverDepth, float lightSize) {
    float blockerDistance = avgBlockerDepth;
    float receiverDistance = receiverDepth;
    float penumbraDistance = receiverDistance - blockerDistance;

    if (penumbraDistance <= 0.0) {
        return 0.0;
    }

    float penumbraWidth = (penumbraDistance / blockerDistance) * lightSize;
    return clamp(penumbraWidth, 0.0, 1.0);
}

float pcssShadowSample(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                       float filterSize, int sampleCount) {
    float shadow = 0.0;

    if (filterSize < 0.001) {
        sampleCount = 4;
    } else if (filterSize < 0.05) {
        sampleCount = 8;
    } else if (filterSize < 0.15) {
        sampleCount = 16;
    } else {
        sampleCount = 32;
    }

    // Cap PCF samples for low-end preset
    sampleCount = min(sampleCount, PCSS_PCF_SAMPLES_CAP);

    for (int i = 0; i < 32; i++) {
        if (i >= sampleCount) break;

        vec2 offset = poissonDisk16[i % 16] * filterSize;
        vec2 samplePos = sampleCoord + offset;
        samplePos = clamp(samplePos, vec2(0.0), vec2(1.0));

        float sampledDepth = texture(shadowMap, samplePos).x;
        if (shadowDepthInvert == 1) sampledDepth = 1.0 - sampledDepth;
        shadow += ((sampledDepth + shadowBias) >= receiverDepth) ? 1.0 : 0.0;
    }

    return shadow / float(sampleCount);
}

float pcssShadow(sampler2D shadowMap, vec2 sampleCoord, float receiverDepth,
                 float lightSize, float searchRadius) {
    // Use reduced blocker samples for low end
    vec3 blockerInfo = pcssBlockerSearch(shadowMap, sampleCoord, receiverDepth,
                                          searchRadius, PCSS_BLOCKER_SAMPLES);
    float avgBlockerDepth = blockerInfo.x;
    float blockerCount = blockerInfo.y;

    if (blockerCount < 0.5) {
        return 1.0;
    }

    float penumbraSize = pcssComputePenumbra(avgBlockerDepth, receiverDepth, lightSize);
    penumbraSize = clamp(penumbraSize, 0.0, 0.1);

    float shadow = pcssShadowSample(shadowMap, sampleCoord, receiverDepth,
                                    penumbraSize, PCSS_PCF_SAMPLES_CAP);

    return shadow;
}

vec3 reconstructWorldPosition(vec2 uv, float depth) {
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth * 2.0 - 1.0);
    vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
    viewPos /= viewPos.w;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    return worldPos.xyz;
}

vec4 projectToShadowSpace(vec3 worldPos) {
    vec4 shadowPos = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    shadowPos /= shadowPos.w;
    vec2 shadowCoord = shadowPos.xy * 0.5 + 0.5;
    float shadowDepth = shadowPos.z * 0.5 + 0.5;
    return vec4(shadowCoord, shadowDepth, shadowPos.w);
}

void main() {
    vec4 baseColor = texture(colortex0, uv);
    float depth = texture(depthtex0, uv).r;
    if (depth > 0.9999) { fragColor = baseColor; return; }
    vec3 worldPos = reconstructWorldPosition(uv, depth);
    vec4 shadowData = projectToShadowSpace(worldPos);
    vec2 shadowCoord = shadowData.xy;
    float shadowDepth = shadowData.z;

    // Lower quality defaults for weaker GPUs
    float lightSize = 0.25;
    float baseSearchRadius = 0.005;
    vec2 ddx = dFdx(shadowCoord);
    vec2 ddy = dFdy(shadowCoord);
    float texelSize = max(length(ddx), length(ddy));
    texelSize = max(texelSize, 1e-5);
    float searchRadius = max(baseSearchRadius, texelSize * 6.0);

    if (debugMode == 4) {
        float debugShadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth, lightSize, searchRadius);
        fragColor = vec4(vec3(debugShadow), baseColor.a);
        return;
    }

    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 || shadowCoord.y < 0.0 || shadowCoord.y > 1.0) {
        fragColor = baseColor; return;
    }

    float shadow = pcssShadow(shadowtex0, shadowCoord, shadowDepth, lightSize, searchRadius);
    vec3 shadowed = baseColor.rgb * (0.5 + shadow * 0.5);
    fragColor = vec4(shadowed, baseColor.a);
}
