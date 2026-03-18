// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║              AIRY DISK & DIFFRACTION SPIKES (PHASE 17)                   ║
// ║                                                                           ║
// ║  Circular aperture diffraction patterns (Airy disk) and polygonal      ║
// ║  aperture diffraction spikes. Models point spread function from        ║
// ║  circular/polygonal apertures, producing realistic point light bloom   ║
// ║  and diffraction effects.                                               ║
// ║                                                                           ║
// ║  Theory: Circular aperture → Airy disk (concentric rings)              ║
// ║  Polygonal aperture (hexagon, square) → diffraction spikes            ║
// ║  Spikes point perpendicular to aperture edges.                        ║
// ║                                                                           ║
// ║  Physics: I(r) = [2×J₁(x)/x]² where J₁ = Bessel function, x depends  ║
// ║  on aperture diameter D, wavelength λ, and radius r.                  ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_AIRY_DISK
#define INCLUDE_AIRY_DISK

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ AIRY PATTERN RENDERING                                                   ║
// ║                                                                           ║
// │ Circular aperture diffraction: Airy disk (primary lobe) surrounded by  │
// │ concentric rings of decreasing intensity. Central disk bright, rings   │
// │ progressively dimmer.                                                   │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ airyIntensity()                                                         ║
// ║                                                                         ║
// │ Computes Airy disk intensity using Bessel J₁ function. Produces       │
// │ characteristic bright central disk with concentric rings.             │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   radius          - Distance from disk center                         │
// │   apertureDiameter - Aperture opening size (normalized)               │
// │   wavelength      - Light wavelength (normalized 0-1)                 │
// │                                                                         ║
// │ Returns: Intensity [0, 1]                                            │
// │                                                                         ║
// │ Physics:                                                                ║
// │   - Formula: I(r) = [2×J₁(x)/x]² where J₁ = Bessel function        │
// │   - x = π×D×r/λ (Fraunhofer parameter)                              │
// │   - Central lobe: x ∈ [0, 3.83) → bright disk                       │
// │   - First ring: x ∈ [3.83, 5.14) → first bright ring (10% intensity)│
// │   - Subsequent rings: progressively dimmer                            │
// └─────────────────────────────────────────────────────────────────────────┘
float airyIntensity(float radius, float apertureDiameter, float wavelength) {
    // ────────────────────────────────────────────────────────────────────────
    // Handle singularity at center: J₁(0) = 0, but lim(2J₁(x)/x) = 1
    // ────────────────────────────────────────────────────────────────────────
    if (radius < 0.0001) return 1.0;

    // ────────────────────────────────────────────────────────────────────────
    // Fraunhofer diffraction parameter: x = π×D×r/λ
    // ────────────────────────────────────────────────────────────────────────
    float x = 3.14159265359 * apertureDiameter * radius / wavelength;

    // ────────────────────────────────────────────────────────────────────────
    // Bessel J₁ function approximation (different formulas for x<8, x≥8)
    // ────────────────────────────────────────────────────────────────────────
    float j1;
    if (x < 8.0) {
        // Direct approximation for small/medium x (most common case)
        // J₁(x) ≈ sin(x)/(x²) - cos(x)/x
        j1 = sin(x) / (x * x) - cos(x) / x;
    } else {
        // Asymptotic approximation for large x (far from center)
        // J₁(x) ≈ √(2/(πx)) × sin(x - 3π/4)
        j1 = sqrt(2.0 / (3.14159265359 * x)) * sin(x - 3.0 * 3.14159265359 / 4.0);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Airy intensity formula: I = [2×J₁(x)/x]²
    // ────────────────────────────────────────────────────────────────────────
    float airy = 2.0 * j1 / x;
    return airy * airy;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ airyDiskPattern()                                                       ║
// ║                                                                         ║
// │ Computes complete Airy disk pattern including primary lobe and rings. │
// │ Uses green wavelength (550nm) as reference, adds ring detail for     │
// │ more realistic appearance.                                             │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord      - Current screen position                          │
// │   centerCoord      - Disk center (light source)                       │
// │   apertureDiameter - Aperture size (normalized)                       │
// │                                                                         ║
// │ Returns: Disk intensity [0, 1]                                       │
// │                                                                         ║
// │ Components:                                                             ║
// │   Primary: Airy disk from J₁ formula (85% weight)                    │
// │   Rings: sinusoidal oscillation (15% weight, subtle detail)           │
// └─────────────────────────────────────────────────────────────────────────┘
float airyDiskPattern(vec2 screenCoord, vec2 centerCoord, float apertureDiameter) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute distance from disk center
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - centerCoord;
    float radius = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Use green wavelength (550nm) as reference for disk size
    // ────────────────────────────────────────────────────────────────────────
    float wavelength = 0.00055;  // 550nm normalized

    // ────────────────────────────────────────────────────────────────────────
    // Primary Airy disk intensity
    // ────────────────────────────────────────────────────────────────────────
    float intensity = airyIntensity(radius, apertureDiameter, wavelength);

    // ────────────────────────────────────────────────────────────────────────
    // Add ring structure for visual detail
    // Oscillates to simulate concentric rings (though simplified)
    // Amplitude decreases with radius (rings fade away)
    // ────────────────────────────────────────────────────────────────────────
    float rings = 0.0;
    if (radius > 0.0) {
        // sin(radius × 100) creates high-frequency oscillation
        // (1 + radius × 50) creates radial falloff envelope
        rings = 0.3 * sin(radius * 100.0) / (1.0 + radius * 50.0);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Combine primary disk (85%) with ring detail (15%)
    // ────────────────────────────────────────────────────────────────────────
    return intensity + rings * 0.1;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL AIRY DISK                                                       ║
// ║                                                                           ║
// │ Per-channel Airy disks for wavelength-specific rendering. Different   │
// │ wavelengths produce Airy disks of different sizes - red larger, blue  │
// │ smaller - creating characteristic iridescent bloom appearance.        │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ SpectralAiry (structure)                                                ║
// ║                                                                         ║
// │ Per-channel Airy disk intensities                                     │
// │   red:   650nm Airy disk (largest disk)                              │
// │   green: 550nm Airy disk (reference)                                 │
// │   blue:  450nm Airy disk (smallest disk)                             │
// └─────────────────────────────────────────────────────────────────────────┘
struct SpectralAiry {
    float red;      // 650nm
    float green;    // 550nm
    float blue;     // 450nm
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralAiryDisk()                                                      ║
// ║                                                                         ║
// │ Computes per-wavelength Airy disks. Each wavelength (RGB) produces   │
// │ its own disk of different size: longer wavelength = larger disk.     │
// │ Creates chromatic aberration effect in Airy bloom.                    │
// │                                                                         ║
// │ Returns: SpectralAiry with per-channel disk intensities              │
// │                                                                         ║
// │ Wavelength-Size Relationship:                                          │
// │   Red (650nm):   largest Airy disk                                   │
// │   Green (550nm): medium Airy disk                                    │
// │   Blue (450nm):  smallest Airy disk                                  │
// │   Creates chromatic dispersion in bloom (rainbow halo effect)        │
// └─────────────────────────────────────────────────────────────────────────┘
SpectralAiry spectralAiryDisk(vec2 screenCoord, vec2 centerCoord, float apertureDiameter) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute distance from disk center
    // ────────────────────────────────────────────────────────────────────────
    vec2 delta = screenCoord - centerCoord;
    float radius = length(delta);

    SpectralAiry result;

    // ────────────────────────────────────────────────────────────────────────
    // RGB wavelengths (normalized to 0-1 scale)
    // Red: 650nm, Green: 550nm, Blue: 450nm
    // ────────────────────────────────────────────────────────────────────────
    float wavelengthRed = 0.00065;    // 650nm
    float wavelengthGreen = 0.00055;  // 550nm
    float wavelengthBlue = 0.00045;   // 450nm

    // ────────────────────────────────────────────────────────────────────────
    // Airy disk for each wavelength (different sizes)
    // Same aperture diameter, but different wavelength → different disk size
    // ────────────────────────────────────────────────────────────────────────
    result.red = airyIntensity(radius, apertureDiameter, wavelengthRed);
    result.green = airyIntensity(radius, apertureDiameter, wavelengthGreen);
    result.blue = airyIntensity(radius, apertureDiameter, wavelengthBlue);

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralAiryToRGB()                                                     ║
// ║                                                                         ║
// │ Converts SpectralAiry to RGB color for rendering                     │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 spectralAiryToRGB(SpectralAiry airy) {
    return vec3(airy.red, airy.green, airy.blue);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ DIFFRACTION SPIKES                                                       ║
// ║                                                                           ║
// │ Spikes from polygonal apertures: hexagon (6), rectangular (4), or      │
// │ octagonal (8) create diffraction spikes converging on light source.   │
// │ Spikes radiate perpendicular to aperture edges.                      │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ hexagonalDiffraction()                                                  ║
// ║                                                                         ║
// │ Computes 6-spike diffraction pattern (hexagonal aperture). Typical    │
// │ for high-end cameras/telescopes. Regular star pattern, 60° spacing.   │
// │                                                                         ║
// │ Returns: Spike intensity [0, 1]                                      │
// │                                                                         ║
// │ Geometry: 6 rays at 0°, 60°, 120°, 180°, 240°, 300°                 │
// │ Each ray: narrow angular profile, exponential radial falloff        │
// └─────────────────────────────────────────────────────────────────────────┘
float hexagonalDiffraction(vec2 screenCoord, vec2 centerCoord) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    float spikePattern = 0.0;
    for (int i = 0; i < 6; i++) {
        float spikeAngle = float(i) * 1.0471975512; // 60° = π/3
        float angleDiff = abs(angle - spikeAngle);

        // Wrap angle to [-π, π]
        if (angleDiff > 3.14159265359) {
            angleDiff = 6.28318530718 - angleDiff;
        }

        // Narrow spike with Gaussian profile
        float spikeWidth = 0.02;
        float spike = max(0.0, 1.0 - (angleDiff * angleDiff) / (spikeWidth * spikeWidth));
        spike *= exp(-radius * 0.5);  // Radial falloff

        spikePattern += spike;
    }

    return spikePattern / 6.0;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rectangularDiffraction()                                                ║
// ║                                                                         ║
// │ 4-spike pattern (rectangular sensor aperture). Horizontal and         │
// │ vertical spikes, with aspect ratio controlling relative widths.      │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   aspectRatio - Width/height (>1 = wider, <1 = taller)              │
// │                                                                         ║
// │ Returns: Spike intensity [0, 1]                                      │
// │                                                                         ║
// │ Geometry: 4 rays at 0°, 90°, 180°, 270°                             │
// │ Horizontal/vertical widths differ based on sensor aspect ratio       │
// └─────────────────────────────────────────────────────────────────────────┘
float rectangularDiffraction(vec2 screenCoord, vec2 centerCoord, float aspectRatio) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    float spikePattern = 0.0;
    for (int i = 0; i < 4; i++) {
        float spikeAngle = float(i) * 1.5707963267; // 90° = π/2
        float angleDiff = abs(angle - spikeAngle);

        if (angleDiff > 3.14159265359) {
            angleDiff = 6.28318530718 - angleDiff;
        }

        // Aspect ratio: alternating spikes have different widths
        float spikeWidth = (i % 2 == 0) ? 0.015 : (0.015 * aspectRatio);
        float spike = max(0.0, 1.0 - (angleDiff * angleDiff) / (spikeWidth * spikeWidth));
        spike *= exp(-radius * 0.7);  // Faster falloff than hexagonal

        spikePattern += spike;
    }

    return spikePattern / 4.0;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ DIFFRACTION CROSS (8-POINTED STAR)                                       ║
// ║                                                                           ║
// │ 8-spike pattern from octagonal aperture. Dense star pattern, 45°     │
// │ spacing. Premium optics (high-end cameras/telescopes).               │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ octagonalDiffraction()                                                  ║
// ║                                                                         ║
// │ 8-spike diffraction pattern (octagonal aperture). Creates dense      │
// │ star-like pattern with 45° spike spacing. Very regular appearance.   │
// │                                                                         ║
// │ Returns: Spike intensity [0, 1]                                      │
// │                                                                         ║
// │ Geometry: 8 rays at 45° intervals                                    │
// │ Creates visually striking symmetric pattern                          │
// └─────────────────────────────────────────────────────────────────────────┘
float octagonalDiffraction(vec2 screenCoord, vec2 centerCoord) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    float spikePattern = 0.0;
    for (int i = 0; i < 8; i++) {
        float spikeAngle = float(i) * 0.7853981634; // 45° = π/4
        float angleDiff = abs(angle - spikeAngle);

        if (angleDiff > 3.14159265359) {
            angleDiff = 6.28318530718 - angleDiff;
        }

        float spikeWidth = 0.01;
        float spike = max(0.0, 1.0 - (angleDiff * angleDiff) / (spikeWidth * spikeWidth));
        spike *= exp(-radius * 0.5);

        spikePattern += spike;
    }

    return spikePattern / 8.0;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ COMPOSITE DIFFRACTION EFFECT                                             ║
// ║                                                                           ║
// │ Combines Airy disk with aperture-specific diffraction spikes.         │
// │ Selects spike type based on apertureType parameter (0=circular,       │
// │ 1=hexagonal, 2=rectangular, 3=octagonal).                             │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ completeDiffractionPattern()                                            ║
// ║                                                                         ║
// │ Master function combining Airy disk + aperture-specific spikes.      │
// │ Selects spike pattern based on apertureType.                          │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord      - Screen position                                  │
// │   centerCoord      - Light center                                     │
// │   apertureDiameter - Disk size (normalized)                          │
// │   apertureType     - Aperture shape (0-3)                            │
// │                                                                         ║
// │ Aperture Types:                                                        │
// │   0: Circular (no spikes, pure Airy disk)                            │
// │   1: Hexagonal (6 spikes, 50% blend)                                 │
// │   2: Rectangular (4 spikes, 40% blend)                               │
// │   3: Octagonal (8 spikes, 60% blend)                                 │
// │                                                                         ║
// │ Returns: Complete diffraction pattern (disk + spikes)                │
// └─────────────────────────────────────────────────────────────────────────┘
float completeDiffractionPattern(
    vec2 screenCoord,
    vec2 centerCoord,
    float apertureDiameter,
    int apertureType
) {
    // ────────────────────────────────────────────────────────────────────────
    // Start with Airy disk (primary diffraction component)
    // ────────────────────────────────────────────────────────────────────────
    float result = airyDiskPattern(screenCoord, centerCoord, apertureDiameter);

    // ────────────────────────────────────────────────────────────────────────
    // Add spikes based on aperture type
    // ────────────────────────────────────────────────────────────────────────
    if (apertureType == 0) {
        // Circular: no spikes
        // result += 0.0;
    } else if (apertureType == 1) {
        // Hexagonal (telescopes, premium cameras): 6 spikes
        result += hexagonalDiffraction(screenCoord, centerCoord) * 0.5;
    } else if (apertureType == 2) {
        // Rectangular (camera sensors): 4 spikes
        result += rectangularDiffraction(screenCoord, centerCoord, 1.5) * 0.4;
    } else if (apertureType == 3) {
        // Octagonal (premium optics): 8 spikes
        result += octagonalDiffraction(screenCoord, centerCoord) * 0.6;
    }

    return result;
}

#endif // INCLUDE_AIRY_DISK
