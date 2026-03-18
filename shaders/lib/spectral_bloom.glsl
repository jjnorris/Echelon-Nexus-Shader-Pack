// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║         SPECTRAL BLOOM & CHROMATIC ABERRATION (PHASE 17)                 ║
// ║                                                                           ║
// ║  Wavelength-dependent light bloom and chromatic aberration effects.      ║
// ║  Spectral decomposition for realistic iridescent blooms, lens flares,   ║
// ║  and color fringing typical of real optical systems.                     ║
// ║                                                                           ║
// ║  Physics: Different wavelengths have different refractive indices and   ║
// ║  focal lengths in lenses. Creates characteristic color separation in   ║
// ║  bloom halos and edge fringing (red outward, blue inward).              ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_SPECTRAL_BLOOM
#define INCLUDE_SPECTRAL_BLOOM

#include "diffraction.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL BLOOM GENERATION                                                ║
// ║                                                                           ║
// │ Wavelength-dependent bloom: red disperses furthest, blue least. Each    │
// │ wavelength has independent dispersion parameter modeling optical        │
// │ wavelength-dependent behavior (dispersion).                              │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ SpectralBloom (structure)                                               ║
// ║                                                                         ║
// │ Per-channel bloom intensity [0, 1]                                     │
// │   red:   650nm wavelength bloom intensity                              │
// │   green: 550nm wavelength bloom intensity                              │
// │   blue:  450nm wavelength bloom intensity                              │
// └─────────────────────────────────────────────────────────────────────────┘
struct SpectralBloom {
    float red;      // 650nm wavelength
    float green;    // 550nm wavelength
    float blue;     // 450nm wavelength
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeSpectralBloom()                                                  ║
// ║                                                                         ║
// │ Computes wavelength-specific bloom for each RGB channel. Each wavelength│
// │ disperses with different width (red most, blue least), creating natural│
// │ color-separated bloom halos.                                            │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord       - Current screen position                          │
// │   lightSourceCoord  - Light source position on screen                  │
// │   lightColor        - Light RGB color [0, 1]                          │
// │   bloomStrength     - Overall bloom magnitude multiplier              │
// │                                                                         ║
// │ Returns: SpectralBloom with per-channel intensities                   │
// │                                                                         ║
// │ Dispersion Model:                                                       │
// │   - Red (650nm):   dispersion = 0.3 × strength (furthest spread)      │
// │   - Green (550nm): dispersion = 0.2 × strength (medium spread)        │
// │   - Blue (450nm):  dispersion = 0.1 × strength (least spread)         │
// │   - Gaussian: width ∝ dispersion (wider = more spread)                │
// │                                                                         ║
// │ Result: Each wavelength has independent bloom halo, slightly offset   │
// │ from each other, creating characteristic spectral bloom appearance    │
// └─────────────────────────────────────────────────────────────────────────┘
SpectralBloom computeSpectralBloom(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    vec3 lightColor,
    float bloomStrength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute distance from screen position to light source
    // Used for Gaussian bloom falloff calculation
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - lightSourceCoord;
    float distance = length(delta);

    SpectralBloom bloom;

    // ────────────────────────────────────────────────────────────────────────
    // Wavelength-dependent dispersion parameters
    // Red light disperses most (larger halo), blue least
    // Models chromatic aberration and dispersion of optical systems
    // ────────────────────────────────────────────────────────────────────────
    float dispersionRed = 0.3 * bloomStrength;      // Red: maximum spread
    float dispersionGreen = 0.2 * bloomStrength;    // Green: medium spread
    float dispersionBlue = 0.1 * bloomStrength;     // Blue: minimum spread

    // ────────────────────────────────────────────────────────────────────────
    // Gaussian bloom for each wavelength
    // G(r) = lightColor × exp(-r² / (2σ²)) where σ = dispersion
    // Wider σ = broader bloom halo with lower peak intensity
    // ────────────────────────────────────────────────────────────────────────
    bloom.red = lightColor.r * exp(-(distance * distance) / (2.0 * dispersionRed * dispersionRed));
    bloom.green = lightColor.g * exp(-(distance * distance) / (2.0 * dispersionGreen * dispersionGreen));
    bloom.blue = lightColor.b * exp(-(distance * distance) / (2.0 * dispersionBlue * dispersionBlue));

    return bloom;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralBloomToRGB()                                                    ║
// ║                                                                         ║
// │ Converts SpectralBloom structure to RGB color for rendering           │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   bloom - SpectralBloom with per-channel intensities                  │
// │                                                                         ║
// │ Returns: RGB color vector                                             │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 spectralBloomToRGB(SpectralBloom bloom) {
    return vec3(bloom.red, bloom.green, bloom.blue);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ CHROMATIC ABERRATION                                                     ║
// ║                                                                           ║
// │ Lens chromatic aberration: wavelength-dependent color fringing. Red    │
// │ and blue channels misaligned, creating characteristic color halos at  │
// │ edges of bright objects (typical of wide-aperture lenses).             │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ chromaticAberrationOffset()                                             ║
// ║                                                                         ║
// │ Computes per-channel aberration offsets (magnitudes). Red offsets     │
// │ least (0.8×), blue offsets most (1.2×), creating wavelength-dependent │
// │ fringing pattern radially from image center.                           │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord    - Current screen position                            │
// │   centerCoord    - Image center (where aberration = 0)                │
// │   apertureAmount - Aberration strength multiplier                     │
// │                                                                         ║
// │ Returns: vec3 offset magnitudes [offsetR, offsetG, offsetB]          │
// │                                                                         ║
// │ Offset Relationship:                                                    │
// │   - Distance from center: determines aberration magnitude              │
// │   - Red (650nm):   0.8× distance × apertureAmount                    │
// │   - Green (550nm): 1.0× distance × apertureAmount                    │
// │   - Blue (450nm):  1.2× distance × apertureAmount                    │
// │   - Edge effect: aberration increases outward from center             │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 chromaticAberrationOffset(
    vec2 screenCoord,
    vec2 centerCoord,
    float apertureAmount
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute radial direction and distance from image center
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - centerCoord;
    vec2 direction = normalize(delta);
    float distance = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Per-channel aberration offsets (wavelength-dependent)
    // Red bends least, blue bends most (inverse of refractive index)
    // ────────────────────────────────────────────────────────────────────────
    float aberrationRed = distance * apertureAmount * 0.8;      // Red: least
    float aberrationGreen = distance * apertureAmount * 1.0;    // Green: medium
    float aberrationBlue = distance * apertureAmount * 1.2;     // Blue: most

    // Return magnitude offsets for each channel
    return vec3(aberrationRed, aberrationGreen, aberrationBlue);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyChromaticAberration()                                              ║
// ║                                                                         ║
// │ Applies chromatic aberration by sampling RGB channels at different    │
// │ positions. Reads red from offset position, green from different       │
// │ offset, blue from yet another, creating misaligned color fringing.    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   colorTexture    - Input color texture to aberrate                   │
// │   screenCoord     - Current screen position being shaded              │
// │   centerCoord     - Image center                                       │
// │   apertureAmount  - Aberration strength                               │
// │   invResolution   - Inverse resolution [1/width, 1/height]            │
// │                                                                         ║
// │ Returns: RGB color with chromatic aberration applied                 │
// │                                                                         ║
// │ Algorithm:                                                              ║
// │   1. Compute aberration offsets for each channel                      │
// │   2. Compute radial direction from center                             │
// │   3. Sample R channel from position - red_offset×direction           │
// │   4. Sample G channel from position - green_offset×direction         │
// │   5. Sample B channel from position - blue_offset×direction          │
// │   6. Return combined RGB (misaligned)                                 │
// │                                                                         ║
// │ Visual Effect:                                                          │
// │   - Red fringe on one side of bright objects                         │
// │   - Blue fringe on opposite side                                     │
// │   - Strength increases away from image center                        │
// │   - Characteristic of real wide-aperture lenses                      │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 applyChromaticAberration(
    sampler2D colorTexture,
    vec2 screenCoord,
    vec2 centerCoord,
    float apertureAmount,
    vec2 invResolution
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute per-channel aberration offset magnitudes
    // ────────────────────────────────────────────────────────────────────────
    vec3 aberration = chromaticAberrationOffset(screenCoord, centerCoord, apertureAmount);

    // ────────────────────────────────────────────────────────────────────────
    // Radial direction: from center outward
    // Used to apply offsets in the direction away from center
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - centerCoord;
    vec2 direction = normalize(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Sample offset positions for each channel
    // Offset is applied in direction × aberrationAmount × invResolution
    // ────────────────────────────────────────────────────────────────────────
    vec2 offsetR = screenCoord - direction * aberration.r * invResolution;
    vec2 offsetG = screenCoord - direction * aberration.g * invResolution;
    vec2 offsetB = screenCoord - direction * aberration.b * invResolution;

    // ────────────────────────────────────────────────────────────────────────
    // Sample each channel from offset position (channel-specific sampling)
    // Creates misaligned RGB = chromatic aberration effect
    // ────────────────────────────────────────────────────────────────────────
    vec3 color;
    color.r = texture(colorTexture, offsetR).r;
    color.g = texture(colorTexture, offsetG).g;
    color.b = texture(colorTexture, offsetB).b;

    return color;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ MULTI-ORDER SPECTRAL BLOOM                                               ║
// ║                                                                           ║
// │ Multi-order blooms: multiple lens reflections creating secondary and   │
// │ tertiary blooms. Models internal reflections within optical system.    │
// │ Secondary bloom fainter and shifted outward (away from light source).  │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ MultiOrderBloom (structure)                                             ║
// ║                                                                         ║
// │ Multiple bloom orders from optical reflections                        │
// │   primary:   Main bloom (100% brightness)                            │
// │   secondary: Secondary bloom (30% brightness, 1.5× distance)         │
// │   tertiary:  Tertiary bloom (10% brightness, 2.5× distance)          │
// └─────────────────────────────────────────────────────────────────────────┘
struct MultiOrderBloom {
    vec3 primary;    // First order (100%)
    vec3 secondary;  // Second order (30% at 1.5×distance)
    vec3 tertiary;   // Third order (10% at 2.5×distance)
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeMultiOrderSpectralBloom()                                        ║
// ║                                                                         ║
// │ Computes all three bloom orders. Each order progressively fainter    │
// │ and shifted further from light source (internal reflections model).   │
// │                                                                         ║
// │ Parameters: [screenCoord, lightSourceCoord, lightColor, bloomStrength]│
// │ Returns: MultiOrderBloom with all three orders                       │
// │                                                                         ║
// │ Order Characteristics:                                                  ║
// │   Primary:   Full brightness, at light center                        │
// │   Secondary: 30% brightness (0.3×color), 1.5× outward distance      │
// │   Tertiary:  10% brightness (0.1×color), 2.5× outward distance      │
// │   Bloom Strength: reduced per order (0.5×, 0.2×)                    │
// └─────────────────────────────────────────────────────────────────────────┘
MultiOrderBloom computeMultiOrderSpectralBloom(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    vec3 lightColor,
    float bloomStrength
) {
    MultiOrderBloom result;
    vec2 delta = screenCoord - lightSourceCoord;
    float distance = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Primary bloom: at light source position
    // ────────────────────────────────────────────────────────────────────────
    SpectralBloom primary = computeSpectralBloom(
        screenCoord, lightSourceCoord, lightColor, bloomStrength
    );
    result.primary = spectralBloomToRGB(primary);

    // ────────────────────────────────────────────────────────────────────────
    // Secondary bloom: shifted outward, fainter
    // Color 30%, strength 50% of primary
    // ────────────────────────────────────────────────────────────────────────
    float secondaryDist = distance * 1.5;
    vec2 secondaryCoord = lightSourceCoord + normalize(delta) * secondaryDist;
    SpectralBloom secondary = computeSpectralBloom(
        screenCoord, secondaryCoord, lightColor * 0.3, bloomStrength * 0.5
    );
    result.secondary = spectralBloomToRGB(secondary);

    // ────────────────────────────────────────────────────────────────────────
    // Tertiary bloom: furthest out, very dim
    // Color 10%, strength 20% of primary
    // ────────────────────────────────────────────────────────────────────────
    float tertiaryDist = distance * 2.5;
    vec2 tertiaryCoord = lightSourceCoord + normalize(delta) * tertiaryDist;
    SpectralBloom tertiary = computeSpectralBloom(
        screenCoord, tertiaryCoord, lightColor * 0.1, bloomStrength * 0.2
    );
    result.tertiary = spectralBloomToRGB(tertiary);

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ combineMultiOrderBloom()                                                ║
// ║                                                                         ║
// │ Sums all bloom orders into single RGB. Simple additive composition.  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 combineMultiOrderBloom(MultiOrderBloom bloom) {
    return bloom.primary + bloom.secondary + bloom.tertiary;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL LENS EFFECTS                                                    ║
// ║                                                                           ║
// │ Lens distortion and optical effects with wavelength variation.         │
// │ Barrel distortion increases outward, with color fringing from         │
// │ wavelength-dependent refractive index differences.                     │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralLensDistortion()                                                ║
// ║                                                                         ║
// │ Computes lens distortion (barrel/pincushion) with barrel geometry.    │
// │ Note: current implementation doesn't use spectral variation in         │
// │ distortion; red/blue have same distortion in this version.            │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord        - Current screen position                        │
// │   lensCenter         - Center of lens distortion                      │
// │   distortionStrength - Barrel distortion magnitude                    │
// │                                                                         ║
// │ Returns: Distorted screen coordinate                                 │
// │                                                                         ║
// │ Physics:                                                                ║
// │   - Distortion: d = 1 + r×k where r=distance, k=strength             │
// │   - newCoord = center + (coord - center) / d                         │
// │   - Pushes pixels outward (barrel) or inward (pincushion)            │
// └─────────────────────────────────────────────────────────────────────────┘
vec2 spectralLensDistortion(
    vec2 screenCoord,
    vec2 lensCenter,
    float distortionStrength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Radial distance from lens center
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - lensCenter;
    float radius = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Barrel distortion: amplify outward displacement
    // d = 1 + r×k×0.1 (k = distortionStrength)
    // ────────────────────────────────────────────────────────────────────────
    float distortion = 1.0 + radius * distortionStrength * 0.1;

    // ────────────────────────────────────────────────────────────────────────
    // Apply distortion: divide to push pixels outward (barrel)
    // newCoord = center + delta / distortion
    // ────────────────────────────────────────────────────────────────────────
    vec2 newCoord = lensCenter + delta / distortion;

    return newCoord;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LENS FLARE ARTIFACTS                                                     ║
// ║                                                                           ║
// │ Simulates internal lens reflections (flare) and diffraction spikes.     │
// │ Flare appears opposite the light source (ghost image), spikes radiate  │
// │ from light with characteristic optical artifacts.                      │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lensFlarePrincipal()                                                    ║
// ║                                                                         ║
// │ Computes principal lens flare (ghost image). Appears roughly opposite  │
// │ light source, with warm golden color typical of lens coating          │
// │ reflections.                                                            ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord      - Current screen position                          │
// │   lightSourceCoord - Light source position (on screen)                │
// │   strength         - Flare intensity multiplier                       │
// │                                                                         ║
// │ Returns: Lens flare RGB color                                        │
// │                                                                         ║
// │ Position:                                                               ║
// │   - Flare at: lightSourceCoord × (-0.5)                              │
// │   - Roughly opposite light source from center                         │
// │   - Gaussian spread around this position                              │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 lensFlarePrincipal(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    float strength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Ghost image position: opposite side of image from light (×-0.5)
    // ────────────────────────────────────────────────────────────────────────
    vec2 flareCoord = lightSourceCoord * (-0.5);
    float flareDist = length(screenCoord - flareCoord);

    // ────────────────────────────────────────────────────────────────────────
    // Gaussian bloom around flare position
    // Warm golden color typical of coated optics
    // ────────────────────────────────────────────────────────────────────────
    float flareBrightness = exp(-(flareDist * flareDist) / 0.02) * strength;
    vec3 flareColor = vec3(1.0, 0.8, 0.6) * flareBrightness;

    return flareColor;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ lensFlareRays()                                                         ║
// ║                                                                         ║
// │ Computes lens flare diffraction spikes (rays). Six-pointed star      │
// │ pattern typical of hexagonal camera apertures. Spikes converge at    │
// │ light source, fade with distance.                                     │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord      - Current screen position                          │
// │   lightSourceCoord - Light source center                              │
// │   rayStrength      - Ray intensity multiplier                         │
// │                                                                         ║
// │ Returns: Ray RGB color                                               │
// │                                                                         ║
// │ Ray Pattern:                                                            ║
// │   - 6 spikes at 60° intervals                                        │
// │   - Gaussian angular profile (narrow rays)                           │
// │   - Exponential radial falloff (fade with distance)                  │
// │   - Warm golden color (coated optics)                                │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 lensFlareRays(
    vec2 screenCoord,
    vec2 lightSourceCoord,
    float rayStrength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute angle and distance from light source
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - lightSourceCoord;
    float angle = atan(delta.y, delta.x);
    float distance = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Create 6 ray pattern (hexagonal aperture, 60° spacing)
    // ────────────────────────────────────────────────────────────────────────
    float rayPattern = 0.0;
    for (int i = 0; i < 6; i++) {
        float rayAngle = float(i) * 3.14159265359 / 3.0;  // 60° spacing
        float angleDiff = abs(angle - rayAngle);
        // Wrap angle difference to [-π, π]
        angleDiff = min(angleDiff, 2.0 * 3.14159265359 - angleDiff);

        // ────────────────────────────────────────────────────────────────────
        // Narrow Gaussian ray: peaks at rayAngle, drops with distance
        // ────────────────────────────────────────────────────────────────────
        rayPattern += exp(-(angleDiff * angleDiff) / 0.01) * exp(-distance * 0.1);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Apply warm color and strength to ray pattern
    // ────────────────────────────────────────────────────────────────────────
    vec3 rayColor = vec3(1.0, 0.8, 0.6) * rayPattern * rayStrength;

    return rayColor;
}

#endif // INCLUDE_SPECTRAL_BLOOM
