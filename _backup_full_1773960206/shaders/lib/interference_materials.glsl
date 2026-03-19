// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║     INTERFERENCE & ADVANCED MATERIALS (PHASE 16)                         ║
// ║     COMPLETE SUB-PHASES 16A-E IMPLEMENTATION                             ║
// ║                                                                           ║
// ║  Optical physics-based material effects including thin-film             ║
// ║  interference, iridescence, diffraction, multilayer materials,         ║
// ║  and wavelength-dependent refraction.                                  ║
// ║                                                                           ║
// ║  Sub-Phases:                                                             ║
// ║    16A: Thin-Film Interference (soap bubbles, oil slicks)              ║
// ║    16B: Iridescence (peacock feathers, CDs)                            ║
// ║    16C: Diffraction Gratings                                           ║
// ║    16D: Layer Materials (Clearcoat + Base)                             ║
// ║    16E: Wavelength-Dependent Refraction                                ║
// ║                                                                           ║
// ║  Applications:                                                           ║
// ║    - Realistic water surfaces with oil-like effects                    ║
// ║    - Iridescent materials (butterfly wings, CDs)                       ║
// ║    - Soap bubbles and thin films                                       ║
// ║    - Multi-layer clearcoat + paint materials                          ║
// ║    - Chromatic aberration in optics                                    ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Born & Wolf (1999) - Principles of Optics                         ║
// ║    - Hecht (2016) - Optics (5th ed.)                                   ║
// ║    - Akenine-Möller et al. (2018) - Real-Time Rendering               ║
// ║    - Pharr et al. (2016) - Physically Based Rendering                  ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_INTERFERENCE_MATERIALS
#define INCLUDE_INTERFERENCE_MATERIALS

#include "constants.glsl"
#include "functions.glsl"

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 16A: THIN-FILM INTERFERENCE                                       ║
// ║                                                                           ║
// │ Optical interference in thin films (soap bubbles, oil slicks).         ║
// │ Constructive/destructive interference creates color from thickness.   ║
// └───────────────────────────────────────────────────────────────────────────┘

float calculateOpticalPathDifference(
    float filmThickness,
    float viewAngle,
    float refractiveIndex
) {
    float sinThetaT = sin(viewAngle) / refractiveIndex;
    float cosThetaT = sqrt(max(0.0, 1.0 - sinThetaT * sinThetaT));
    float opd = 2.0 * refractiveIndex * filmThickness * cosThetaT;
    return opd;
}

vec3 thinFilmInterferenceColor(
    float filmThickness,
    float viewAngle,
    float refractiveIndex
) {
    float opd = calculateOpticalPathDifference(filmThickness, viewAngle, refractiveIndex);

    float redWavelength = 650.0;
    float greenWavelength = 530.0;
    float blueWavelength = 460.0;

    float redInterference = (1.0 + cos(2.0 * PI * opd / redWavelength)) / 2.0;
    float greenInterference = (1.0 + cos(2.0 * PI * opd / greenWavelength)) / 2.0;
    float blueInterference = (1.0 + cos(2.0 * PI * opd / blueWavelength)) / 2.0;

    float fresnel = pow(sin(viewAngle), 2.0);
    float intensity = 0.3 + 0.7 * fresnel;

    return vec3(redInterference, greenInterference, blueInterference) * intensity;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 16B: IRIDESCENCE                                                  ║
// ║                                                                           ║
// │ Wavelength-dependent color shift with viewing angle (peacock,         ║
// │ butterfly wings, CDs). Combines thin-film and diffraction effects.   ║
// └───────────────────────────────────────────────────────────────────────────┘

float iridescenceStrength(float normalDotView, float thickness) {
    float fresnel = pow(1.0 - normalDotView, 2.5);
    float thicknessFactor = 1.0 / (1.0 + thickness / 100.0);
    return fresnel * thicknessFactor;
}

vec3 iridescenceColor(float normalDotLight, float normalDotView) {
    float hue = normalDotLight * 360.0;
    float h = mod(hue / 60.0, 6.0);
    float c = (1.0 - normalDotView) * 0.8;
    float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));

    vec3 rgb;
    if (h < 1.0) rgb = vec3(c, x, 0.0);
    else if (h < 2.0) rgb = vec3(x, c, 0.0);
    else if (h < 3.0) rgb = vec3(0.0, c, x);
    else if (h < 4.0) rgb = vec3(0.0, x, c);
    else if (h < 5.0) rgb = vec3(x, 0.0, c);
    else rgb = vec3(c, 0.0, x);

    float m = 0.3 + 0.5 * normalDotView;
    return rgb + vec3(m);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 16C: DIFFRACTION GRATINGS                                         ║
// ║                                                                           ║
// │ Light diffraction through periodic structures (CDs, DVDs).           ║
// │ Creates rainbow-like spectrum from grooves.                         ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 diffractionGratingSpectrum(
    float grooveSpacing,
    float incidentAngle,
    float normalDotView
) {
    float order = 1.0 + 2.0 * normalDotView;

    float redWavelength = 650.0e-3;
    float greenWavelength = 530.0e-3;
    float blueWavelength = 460.0e-3;

    float d = grooveSpacing;

    float redAngle = asin(clamp(sin(incidentAngle) + order * redWavelength / d, -1.0, 1.0));
    float greenAngle = asin(clamp(sin(incidentAngle) + order * greenWavelength / d, -1.0, 1.0));
    float blueAngle = asin(clamp(sin(incidentAngle) + order * blueWavelength / d, -1.0, 1.0));

    float redIntensity = pow(sin(redAngle * 2.0), 2.0);
    float greenIntensity = pow(sin(greenAngle * 2.0), 2.0);
    float blueIntensity = pow(sin(blueAngle * 2.0), 2.0);

    redIntensity = clamp(redIntensity, 0.0, 1.0);
    greenIntensity = clamp(greenIntensity, 0.0, 1.0);
    blueIntensity = clamp(blueIntensity, 0.0, 1.0);

    return vec3(redIntensity, greenIntensity, blueIntensity);
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 16D: LAYER MATERIALS (CLEARCOAT + BASE)                          ║
// ║                                                                           ║
// │ Multi-layer materials with separate BRDFs for each layer.            ║
// │ Typical use: Clearcoat (glossy) + Paint (matte/metallic base).       ║
// └───────────────────────────────────────────────────────────────────────────┘

float clearcoatFresnel(float cosTheta, float ior) {
    float f0 = pow((ior - 1.0) / (ior + 1.0), 2.0);
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

vec3 multilayerBRDF(
    vec3 baseColor,
    float baseCosTheta,
    float clearcoatCosTheta,
    float clearcoatRoughness
) {
    float f_coat = clearcoatFresnel(clearcoatCosTheta, 1.5);
    float d_coat = pow(clearcoatRoughness, 4.0);
    vec3 clearcoatReflection = vec3(f_coat * d_coat);

    float transmission = 1.0 - f_coat;

    float baseDiffuse = max(0.0, baseCosTheta);
    float baseSpecular = pow(baseCosTheta, 10.0);
    vec3 baseReflection = baseColor * (baseDiffuse * 0.3 + baseSpecular * 0.7);

    return clearcoatReflection + transmission * baseReflection;
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║ PHASE 16E: WAVELENGTH-DEPENDENT REFRACTION                             ║
// ║                                                                           ║
// │ Chromatic aberration: different wavelengths refract at different    ║
// │ angles. Creates color fringing in transparent objects.             ║
// └───────────────────────────────────────────────────────────────────────────┘

float refractiveIndexForWavelength(
    float wavelength,
    float baseIOR,
    float abbe
) {
    float refWavelength = 589.0;
    float dispersion = (baseIOR - 1.0) / abbe;
    float wavelengthRatio = refWavelength / wavelength;
    float deltaIOR = dispersion * (wavelengthRatio * wavelengthRatio - 1.0);
    return baseIOR + deltaIOR;
}

vec3 chromaticAberration(
    vec3 incidentDirection,
    vec3 surfaceNormal,
    float baseIOR,
    float abbe
) {
    float redWavelength = 650.0;
    float greenWavelength = 530.0;
    float blueWavelength = 460.0;

    float redIOR = refractiveIndexForWavelength(redWavelength, baseIOR, abbe);
    float greenIOR = refractiveIndexForWavelength(greenWavelength, baseIOR, abbe);
    float blueIOR = refractiveIndexForWavelength(blueWavelength, baseIOR, abbe);

    float cosI = abs(dot(incidentDirection, surfaceNormal));
    float avgIOR = (redIOR + greenIOR + blueIOR) / 3.0;

    float sinT = sin(acos(cosI)) / avgIOR;
    float cosT = sqrt(max(0.0, 1.0 - sinT * sinT));

    vec3 tangent = normalize(cross(surfaceNormal, incidentDirection));
    return normalize(
        tangent * sin(acos(cosT)) +
        surfaceNormal * cosT
    );
}

vec3 chromaticAberrationColor(
    vec3 originalColor,
    float aberrationAmount,
    vec2 screenCoord
) {
    vec3 aberratedColor = vec3(
        originalColor.r * (1.0 - aberrationAmount * 0.2),
        originalColor.g,
        originalColor.b * (1.0 + aberrationAmount * 0.2)
    );
    return aberratedColor;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ UNIFIED INTERFERENCE & MATERIAL APPLICATION                              ║
// └───────────────────────────────────────────────────────────────────────────┘

vec3 applyInterferenceMaterial(
    vec3 baseColor,
    vec3 normal,
    vec3 viewDir,
    vec3 lightDir,
    int materialType,
    float thickness,
    float ior,
    float abbe
) {
    float nv = clamp(dot(normal, viewDir), 0.0, 1.0);
    float nl = clamp(dot(normal, lightDir), 0.0, 1.0);

    if (materialType == 0) {
        vec3 interference = thinFilmInterferenceColor(thickness, acos(nv), ior);
        return mix(baseColor, interference, 0.7);
    }
    else if (materialType == 1) {
        float iridAmount = iridescenceStrength(nv, thickness);
        vec3 iridColor = iridescenceColor(nl, nv);
        return mix(baseColor, iridColor, iridAmount);
    }
    else if (materialType == 2) {
        vec3 spectrum = diffractionGratingSpectrum(thickness, acos(nl), nv);
        return mix(baseColor, spectrum, 0.6);
    }
    else if (materialType == 3) {
        vec3 layered = multilayerBRDF(baseColor, nl, nv, thickness);
        return layered;
    }
    else if (materialType == 4) {
        vec3 aberrated = chromaticAberrationColor(baseColor, abbe * 0.1, vec2(0.5));
        return aberrated;
    }

    return baseColor;
}

#endif  // INCLUDE_INTERFERENCE_MATERIALS
