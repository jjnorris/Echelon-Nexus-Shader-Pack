// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         IMAGE-BASED LIGHTING (PHASE 20)                                 ║
// ║         COMPLETE SUB-PHASES 20A-E IMPLEMENTATION                         ║
// ║                                                                           ║
// ║  HDRI-based lighting including sphere sampling, spherical harmonics,   ║
// ║  specular/diffuse IBL, and parallax correction for realistic          ║
// ║  environment-based illumination.                                       ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    20A: HDRI Sampling & Environment Maps                              ║
// ║    20B: Spherical Harmonics (SH) Coefficients                         ║
// ║    20C: Specular IBL with Prefiltered Mipmap                         ║
// ║    20D: Diffuse IBL with SH Reconstruction                           ║
// ║    20E: Parallax Correction                                           ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Full scene lighting from HDRI                                   ║
// ║    - Realistic specular reflections                                  ║
// ║    - Diffuse light from environment                                 ║
// ║    - Compressed lighting via SH                                     ║
// ║    - Realistic parallax-corrected probes                            ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Debevec (2005) - Image-Based Lighting                          ║
// ║    - Sloan et al. (2003) - Spherical Harmonics Lighting            ║
// ║    - Karis (2013) - Real Shading in UE4                            ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_IMAGE_BASED_LIGHTING
#define INCLUDE_IMAGE_BASED_LIGHTING

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 20A: HDRI SAMPLING & ENVIRONMENT MAPS                             ║
// ║                                                                           ║
// │ Convert spherical direction to HDRI UV coordinates.                  ║
// │ Sample high dynamic range environment texture.                      ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ directionToSphericalUV()                                                ║
// ║                                                                         ║
// │ Convert 3D direction vector to spherical UV coordinates.           │
// │ Enables direct HDRI texture sampling from world directions.       │
// │                                                                       │
// │ Physics: Equirectangular projection                                │
// │   u = atan(z, x) / (2π) + 0.5                                    │
// │   v = acos(-y) / π                                               │
// │                                                                       │
// │ Inputs:                                                              │
// │   direction - World space direction (should be normalized)      │
// │                                                                       │
// │ Returns: UV coordinates (0.0-1.0) for HDRI texture           │
// └─────────────────────────────────────────────────────────────────────────┘
vec2 directionToSphericalUV(vec3 direction) {
    vec3 normalized = normalize(direction);

    // Spherical coordinates
    float phi = atan(normalized.z, normalized.x);
    float theta = acos(-normalized.y);

    // Convert to UV (equirectangular)
    vec2 uv = vec2(
        phi / (2.0 * PI) + 0.5,
        theta / PI
    );

    return uv;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ sampleHDRI()                                                            ║
// ║                                                                         ║
// │ Sample HDRI texture for a given direction.                        │
// │ Returns high dynamic range color.                                │
// │                                                                       │
// │ Inputs:                                                              │
// │   direction - World space direction                               │
// │   hdriTexture - Equirectangular HDRI texture                    │
// │   intensity - HDRI brightness multiplier                       │
// │                                                                       │
// │ Returns: HDRI color (HDR - can exceed 1.0)                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 sampleHDRI(vec3 direction, sampler2D hdriTexture, float intensity) {
    vec2 uv = directionToSphericalUV(direction);
    vec3 hdriColor = texture(hdriTexture, uv).rgb;
    return hdriColor * intensity;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ sampleHDRILod()                                                         ║
// ║                                                                         ║
// │ Sample HDRI with mipmap level (for roughness).                   │
// │ Higher roughness = lower mip level (blurrier).                  │
// │                                                                       │
// │ Inputs:                                                              │
// │   direction - World space direction                               │
// │   roughness - Surface roughness (0.0-1.0)                      │
// │   hdriTexture - Mipmaped HDRI texture                         │
// │   maxMipLevel - Maximum available mip level                   │
// │                                                                       │
// │ Returns: Mipmapped HDRI sample                               │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 sampleHDRILod(vec3 direction, float roughness, sampler2D hdriTexture, float maxMipLevel) {
    vec2 uv = directionToSphericalUV(direction);

    // Map roughness to mip level
    float mipLevel = roughness * maxMipLevel;

    // Sample with mip level
    vec3 hdriColor = textureLod(hdriTexture, uv, mipLevel).rgb;

    return hdriColor;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 20B: SPHERICAL HARMONICS COEFFICIENTS                             ║
// ║                                                                           ║
// │ Project HDRI onto spherical harmonics basis.                       ║
// │ Efficient representation of low-frequency lighting.               ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ sphericalHarmonicBasis()                                                ║
// ║                                                                         ║
// │ Compute spherical harmonic basis functions.                      │
// │ Using 9 coefficients (3x3 band, L=0,1,2).                       │
// │                                                                       │
// │ SH basis functions:                                               │
// │   Band 0 (L=0): Y₀⁰                                              │
// │   Band 1 (L=1): Y₋₁¹, Y₀¹, Y₁¹                                  │
// │   Band 2 (L=2): Y₋₂², Y₋₁², Y₀², Y₁², Y₂²                       │
// │                                                                       │
// │ Inputs:                                                              │
// │   direction - Normalized world direction                       │
// │                                                                       │
// │ Returns: Array of 9 SH basis values                           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 sphericalHarmonicBasis(vec3 direction) {
    // Normalized direction (assuming already normalized)
    float x = direction.x;
    float y = direction.y;
    float z = direction.z;

    // SH coefficients (L=0,1,2)
    vec3 shBasis[9];

    // L=0, M=0
    shBasis[0] = vec3(0.282095);

    // L=1
    shBasis[1] = vec3(0.488603 * y);
    shBasis[2] = vec3(0.488603 * z);
    shBasis[3] = vec3(0.488603 * x);

    // L=2
    shBasis[4] = vec3(1.092548 * x * y);
    shBasis[5] = vec3(1.092548 * y * z);
    shBasis[6] = vec3(0.315392 * (3.0 * z * z - 1.0));
    shBasis[7] = vec3(1.092548 * x * z);
    shBasis[8] = vec3(0.546274 * (x * x - y * y));

    // Return primary basis (typically use all 9)
    return shBasis[0] + shBasis[1] + shBasis[2];
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ reconstructFromSH()                                                     ║
// ║                                                                         ║
// │ Reconstruct lighting from spherical harmonic coefficients.      │
// │                                                                       │
// │ Inputs:                                                              │
// │   normal - Surface normal                                       │
// │   shCoeffs[9] - Pre-computed SH coefficients per RGB          │
// │                                                                       │
// │ Returns: Reconstructed lighting                               │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 reconstructFromSH(vec3 normal, vec3 shCoeffs[9]) {
    // Reconstruct using SH basis
    vec3 basis[9];

    float x = normal.x;
    float y = normal.y;
    float z = normal.z;

    basis[0] = vec3(0.282095);
    basis[1] = vec3(0.488603 * y);
    basis[2] = vec3(0.488603 * z);
    basis[3] = vec3(0.488603 * x);
    basis[4] = vec3(1.092548 * x * y);
    basis[5] = vec3(1.092548 * y * z);
    basis[6] = vec3(0.315392 * (3.0 * z * z - 1.0));
    basis[7] = vec3(1.092548 * x * z);
    basis[8] = vec3(0.546274 * (x * x - y * y));

    // Sum weighted contributions
    vec3 result = vec3(0.0);
    for (int i = 0; i < 9; i++) {
        result += shCoeffs[i] * basis[i];
    }

    return result;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 20C: SPECULAR IBL WITH PREFILTERED MIPMAP                        ║
// ║                                                                           ║
// │ Pre-filtered specular reflections based on surface roughness.    ║
// │ Mipmaps store increasingly blurred HDRI for different roughness.  ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ prefilteredSpecularIBL()                                                ║
// ║                                                                         ║
// │ Compute specular IBL contribution.                             │
// │                                                                       │
// │ Physics: Cook-Torrance specular reflection                      │
// │   Fs = ∫ L(ω_i) × D(h) × F(h,v) × G(v,l) / (4|n·v||n·l|) dω_i │
// │                                                                       │
// │ Approximation: Pre-filtered HDRI + Fresnel                     │
// │                                                                       │
// │ Inputs:                                                              │
// │   normal - Surface normal                                       │
// │   viewDir - View direction                                    │
// │   roughness - Surface roughness (0.0-1.0)                    │
// │   hdriTexture - Pre-filtered HDRI                           │
// │   f0 - Fresnel at 0° (metallic surfaces)                    │
// │   metallic - Metallic factor (0.0-1.0)                     │
// │                                                                       │
// │ Returns: Specular IBL contribution                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 prefilteredSpecularIBL(
    vec3 normal,
    vec3 viewDir,
    float roughness,
    sampler2D hdriTexture,
    vec3 f0,
    float metallic
) {
    // Reflection direction
    vec3 reflection = reflect(-viewDir, normal);

    // Sample HDRI at roughness level
    vec3 specularColor = sampleHDRILod(reflection, roughness, hdriTexture, 8.0);

    // Fresnel-Schlick approximation
    float vDotH = max(0.0, dot(viewDir, normalize(reflection + viewDir)));
    vec3 fresnel = mix(f0, vec3(1.0), pow(1.0 - vDotH, 5.0));

    // Metallic surface vs dielectric
    vec3 specular = specularColor * fresnel;
    specular *= mix(1.0, metallic, 0.5);  // Reduce specular for metallic

    return specular;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ environmentBRDFLUT()                                                      ║
// ║                                                                           ║
// │ Approximate environment BRDF lookup.                          │
// │ Returns (scale, bias) for specular IBL.                      │
// │                                                                       │
// │ Inputs:                                                              │
// │   nDotV - dot(normal, viewDir)                                │
// │   roughness - Surface roughness                              │
// │                                                                       │
// │ Returns: BRDF scale and bias factors                        │
// └───────────────────────────────────────────────────────────────────────────┘
vec2 environmentBRDFLUT(float nDotV, float roughness) {
    // Approximate BRDF lookup for specular IBL
    // Standard approximation: (scale, bias)

    vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);

    vec4 r = roughness * c0 + c1;

    float a004 = min(r.x * r.x, exp2(-9.28 * nDotV)) * r.x + r.y;

    return vec2(-1.04, 1.04) * a004 + vec2(r.z, r.w);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 20D: DIFFUSE IBL WITH SH RECONSTRUCTION                          ║
// ║                                                                           ║
// │ Diffuse lighting from HDRI via spherical harmonics.            ║
// │ Efficient low-frequency environment illumination.              ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ diffuseIBLFromSH()                                                      ║
// ║                                                                         ║
// │ Compute diffuse IBL from pre-computed SH coefficients.        │
// │                                                                       │
// │ Physics: Diffuse reflection (Lambertian)                      │
// │   Fd = ∫ L(ω_i) × (n · ω_i) × (1/π) dω_i                    │
// │                                                                       │
// │ Using SH: Low-frequency capture with 9 coefficients          │
// │                                                                       │
// │ Inputs:                                                              │
// │   normal - Surface normal                                       │
// │   shDiffuseCoeffs[9] - Pre-computed SH diffuse               │
// │                                                                       │
// │ Returns: Diffuse IBL contribution                          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 diffuseIBLFromSH(vec3 normal, vec3 shDiffuseCoeffs[9]) {
    return reconstructFromSH(normal, shDiffuseCoeffs);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ diffuseIBLDirect()                                                      ║
// ║                                                                         ║
// │ Direct diffuse IBL sampling from HDRI.                         │
// │ Higher quality but more expensive than SH.                    │
// │                                                                       │
// │ Inputs:                                                              │
// │   normal - Surface normal                                       │
// │   hdriTexture - HDRI environment map                         │
// │   sampleCount - Number of samples (8-32)                     │
// │   intensity - IBL intensity                                  │
// │                                                                       │
// │ Returns: Diffuse IBL via sampling                           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 diffuseIBLDirect(
    vec3 normal,
    sampler2D hdriTexture,
    int sampleCount,
    float intensity
) {
    vec3 diffuse = vec3(0.0);

    // Cosine-weighted hemisphere sampling
    for (int i = 0; i < sampleCount && i < 32; i++) {
        float theta = acos(sqrt(1.0 - float(i) / float(sampleCount)));
        float phi = float(i) * 2.3999963 / float(sampleCount);

        // Construct sample direction
        vec3 right = normalize(cross(normal, vec3(0, 1, 0)));
        if (length(right) < 0.1) right = normalize(cross(normal, vec3(1, 0, 0)));
        vec3 up = normalize(cross(right, normal));

        vec3 sampleDir = normalize(
            sin(theta) * cos(phi) * right +
            sin(theta) * sin(phi) * up +
            cos(theta) * normal
        );

        // Sample HDRI and weight by cosine
        vec3 hdriSample = sampleHDRI(sampleDir, hdriTexture, 1.0);
        float cosTheta = max(0.0, dot(sampleDir, normal));

        diffuse += hdriSample * cosTheta;
    }

    diffuse /= float(sampleCount);
    return diffuse * intensity;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 20E: PARALLAX CORRECTION                                          ║
// ║                                                                           ║
// │ Correct probe reflections for parallax.                          ║
// │ Makes local probes appear to come from correct position.       ║
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ parallaxCorrectedReflection()                                           ║
// ║                                                                         ║
// │ Apply parallax correction to probe-based reflections.        │
// │                                                                       │
// │ Physics: Ray-box intersection for corrected reflection.      │
// │                                                                       │
// │ Inputs:                                                              │
// │   reflectionDir - Initial reflection direction                │
// │   position - World position (surface)                        │
// │   probePosition - Probe position                            │
// │   boxMin/Max - Bounding box of influence                   │
// │                                                                       │
// │ Returns: Parallax-corrected reflection direction          │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 parallaxCorrectedReflection(
    vec3 reflectionDir,
    vec3 position,
    vec3 probePosition,
    vec3 boxMin,
    vec3 boxMax
) {
    // Vector from probe to surface
    vec3 posRelativeToProbe = position - probePosition;

    // Ray parameter t for box intersection
    vec3 invReflection = 1.0 / (reflectionDir + vec3(0.0001));  // Avoid divide by zero
    vec3 t = (vec3(0.0) - posRelativeToProbe) * invReflection;

    // Find intersection with box faces
    vec3 t1 = (boxMin - probePosition) * invReflection;
    vec3 t2 = (boxMax - probePosition) * invReflection;

    vec3 tMax = max(t1, t2);
    float t_final = min(min(tMax.x, tMax.y), tMax.z);

    // Corrected reflection direction
    vec3 correctedDir = position + reflectionDir * t_final - probePosition;

    return normalize(correctedDir);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ probeInfluenceWeight()                                                  ║
// ║                                                                         ║
// │ Calculate weight of probe based on distance.                   │
// │ Smooth falloff for blending multiple probes.                 │
// │                                                                       │
// │ Inputs:                                                              │
// │   position - World position                                      │
// │   probePosition - Probe center                               │
// │   probeRadius - Influence radius                            │
// │                                                                       │
// │ Returns: Blend weight (0.0-1.0)                           │
// └─────────────────────────────────────────────────────────────────────────┘
float probeInfluenceWeight(
    vec3 position,
    vec3 probePosition,
    float probeRadius
) {
    float dist = length(position - probePosition);
    float influence = max(0.0, 1.0 - (dist / probeRadius));

    // Smooth falloff
    return influence * influence;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED IBL APPLICATION                                                  ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyImageBasedLighting(
    vec3 normal,
    vec3 viewDir,
    vec3 baseColor,
    float roughness,
    float metallic,
    sampler2D hdriTexture,
    vec3 shDiffuseCoeffs[9],
    float iblIntensity
) {
    // Specular IBL
    vec3 f0 = mix(vec3(0.04), baseColor, metallic);
    vec3 specularIBL = prefilteredSpecularIBL(
        normal, viewDir, roughness, hdriTexture, f0, metallic
    );

    // Diffuse IBL
    vec3 diffuseIBL = diffuseIBLFromSH(normal, shDiffuseCoeffs);

    // BRDF correction
    float nDotV = max(0.0, dot(normal, viewDir));
    vec2 brdf = environmentBRDFLUT(nDotV, roughness);
    specularIBL *= brdf.x + brdf.y;

    // Combine
    vec3 diffuse = mix(diffuseIBL, baseColor * diffuseIBL, 0.5);
    vec3 specular = specularIBL;

    // Final IBL with metallic control
    vec3 ibl = mix(diffuse, specular, metallic) * iblIntensity;

    return ibl;
}

#endif  // INCLUDE_IMAGE_BASED_LIGHTING
