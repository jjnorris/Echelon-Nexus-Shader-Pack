// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║                 DIFFRACTION-BASED EFFECTS (PHASE 17)                     ║
// ║                                                                           ║
// ║  Wave-based diffraction patterns for caustics, god rays, lens artifacts, ║
// ║  and diffraction spike effects using Fresnel and Fraunhofer diffraction. ║
// ║                                                                           ║
// ║  Theory: Diffraction occurs when waves encounter obstacles or apertures. ║
// ║  Fresnel diffraction (near-field): complex spiral patterns, depends on  ║
// ║  distance and geometry. Fraunhofer diffraction (far-field): classic     ║
// ║  patterns (single/double slit, diffraction grating).                     ║
// ║                                                                           ║
// ║  References:                                                             ║
// ║    - Born & Wolf (1999) - Fresnel Equations and Diffraction Theory      ║
// ║    - Wyman (2011) - Caustics and Refraction by Light Field Analysis     ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_DIFFRACTION
#define INCLUDE_DIFFRACTION

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ FRESNEL DIFFRACTION SIMULATION                                           ║
// ║                                                                           ║
// │ Computes near-field diffraction patterns using Fresnel integrals.       │
// │ Fresnel number determines diffraction regime: high F = geometric optics │
// │ (straight shadows), low F = strong wave diffraction (spreading/bending).│
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ fresnelDiffraction()                                                    ║
// ║                                                                         ║
// │ Computes Fresnel diffraction intensity at a point using approximate    │
// │ Fresnel integrals. Produces oscillating diffraction patterns near      │
// │ obstacles (knife-edge, apertures).                                     │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord       - Screen position (or position relative to obstacle)│
// │   wavelength        - Light wavelength in nm (normalized to 0-1)       │
// │   obstacleDistance  - Distance to obstacle/aperture (normalized)       │
// │                                                                         ║
// │ Returns: Intensity [0, 1] from diffraction pattern                    │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Fresnel number F = a² / (λ × z) determines diffraction strength    │
// │   - High F: geometric optics (straight boundaries)                     │
// │   - Low F: strong diffraction (wave spreading)                        │
// │   - Oscillating pattern encodes phase information from Fresnel zones   │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Soft shadows near obstacles                                        │
// │   - Bloom and halo effects around bright objects                       │
// │   - Wave-like artifact patterns in high-magnification rendering        │
// └─────────────────────────────────────────────────────────────────────────┘
float fresnelDiffraction(vec2 screenCoord, float wavelength, float obstacleDistance) {
    // ────────────────────────────────────────────────────────────────────────
    // Fresnel number: F = a² / (λ × z)
    // Controls transition from geometric (large F) to wave (small F) regime
    // ────────────────────────────────────────────────────────────────────────
    float fresnelNum = pow(obstacleDistance, 2.0) / (wavelength * 10.0);

    // ────────────────────────────────────────────────────────────────────────
    // Approximate Fresnel integral with oscillating term
    // Phase encodes position within Fresnel zone system
    // ────────────────────────────────────────────────────────────────────────
    float phase = 3.14159265359 * fresnelNum * dot(screenCoord, screenCoord);

    // ────────────────────────────────────────────────────────────────────────
    // Cosine gives oscillating intensity pattern characteristic of diffraction
    // Normalized to [0.5, 1.0] for positive intensity
    // ────────────────────────────────────────────────────────────────────────
    float diffraction = 0.5 + 0.5 * cos(phase);

    return diffraction;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SINGLE-SLIT & DOUBLE-SLIT DIFFRACTION (FRAUNHOFER)                      ║
// ║                                                                           ║
// │ Far-field diffraction patterns: simple mathematical forms suitable      │
// │ for rendering. Used for basic diffraction spike and bloom effects.      │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ singleSlitDiffraction()                                                 ║
// ║                                                                         ║
// │ Computes single-slit Fraunhofer diffraction intensity pattern.         │
// │ Produces characteristic sinc²() pattern with central lobe and          │
// │ symmetrical weaker side lobes. Classic diff raction pattern.           │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle      - Observation angle from optical axis (radians)           │
// │   slitWidth  - Slit opening width (normalized 0-1)                     │
// │   wavelength - Light wavelength (normalized 0-1)                       │
// │                                                                         ║
// │ Returns: Intensity [0, 1]                                              │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Formula: I(θ) = sinc²(β) where β = π×a×sin(θ)/λ                  │
// │   - Central lobe: bright, width = 2λ/a                                │
// │   - Side lobes: alternate bright/dark, rapidly dimming                │
// │   - First minimum at: sin(θ) = λ/a                                    │
// │                                                                         ║
// │ Use Case: Soft aperture bloom, diffraction blur in depth of field     │
// └─────────────────────────────────────────────────────────────────────────┘
float singleSlitDiffraction(float angle, float slitWidth, float wavelength) {
    // ────────────────────────────────────────────────────────────────────────
    // Diffraction parameter: β = π × a × sin(θ) / λ
    // Controls number of diffraction lobes and pattern structure
    // ────────────────────────────────────────────────────────────────────────
    float beta = 3.14159265359 * slitWidth * sin(angle) / wavelength;

    // ────────────────────────────────────────────────────────────────────────
    // Avoid division by zero: sinc(0) = 1
    // ────────────────────────────────────────────────────────────────────────
    if (abs(beta) < 0.001) return 1.0;

    // ────────────────────────────────────────────────────────────────────────
    // Sinc function: sin(x)/x, then squared for intensity
    // I = sinc²(β) = (sin(β)/β)²
    // ────────────────────────────────────────────────────────────────────────
    float sinc = sin(beta) / beta;
    return sinc * sinc;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ doubleSlitInterference()                                                ║
// ║                                                                         ║
// │ Computes double-slit interference pattern. Combines single-slit        │
// │ diffraction envelope with interference fringes from two slit openings. │
// │ Produces alternating bright/dark bands characteristic of coherent      │
// │ light from two sources.                                                │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle            - Observation angle (radians)                       │
// │   slitSeparation   - Distance between slits (normalized 0-1)           │
// │   wavelength       - Light wavelength (normalized 0-1)                 │
// │                                                                         ║
// │ Returns: Intensity [0, 1]                                              │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Path difference: Δ = d × sin(θ) between two slits                 │
// │   - Phase difference: δ = 2π × Δ / λ                                  │
// │   - Intensity: I = cos²(δ/2) - modulates single-slit envelope         │
// │   - Bright fringes when: d×sin(θ) = m×λ (m=0,±1,±2,...)             │
// │   - Fringe spacing: Δθ ≈ λ/d                                          │
// │                                                                         ║
// │ Combined Pattern:                                                       ║
// │   - Single slit (sinc²) provides overall envelope                      │
// │   - Double slit (cos²) adds high-frequency fringes                    │
// │   - Product gives realistic double-slit appearance                     │
// └─────────────────────────────────────────────────────────────────────────┘
float doubleSlitInterference(float angle, float slitSeparation, float wavelength) {
    // ────────────────────────────────────────────────────────────────────────
    // Phase difference from path length difference between slits
    // Path difference: Δ = d × sin(θ) where d = slit separation
    // Phase: δ = 2π × Δ / λ = π × d × sin(θ) / wavelength
    // ────────────────────────────────────────────────────────────────────────
    float delta = 3.14159265359 * slitSeparation * sin(angle) / wavelength;

    // ────────────────────────────────────────────────────────────────────────
    // Interference formula: I = cos²(δ/2)
    // Oscillates between 1 (constructive: δ=2πm) and 0 (destructive: δ=(2m+1)π)
    // ────────────────────────────────────────────────────────────────────────
    float interference = cos(delta * 0.5);
    return interference * interference;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ DIFFRACTION GRATING                                                      ║
// ║                                                                           ║
// │ Periodic array of slits producing strong spectral dispersion. Each     │
// │ wavelength has specific angle for constructive interference - basis    │
// │ for wavelength-dependent color rendering (spectral bloom, rainbow).    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ diffractionGrating()                                                    ║
// ║                                                                         ║
// │ Computes diffraction grating intensity for given angle and wavelength. │
// │ Uses grating equation to find peak response angles for wavelengths.   │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle            - Observation angle from grating normal (radians)   │
// │   gratingSpacing   - Distance between adjacent slits (normalized 0-1)  │
// │   wavelengthNorm   - Light wavelength (normalized 0-1, typical 0.4-0.7)│
// │   order            - Diffraction order (m=0 zero, ±1,±2,... higher)   │
// │                                                                         ║
// │ Returns: Intensity [0, 1] peak around expected angle for wavelength   │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Grating equation: d × sin(θ) = m × λ                              │
// │   - For each wavelength: expected angle = arcsin(m×λ/d)               │
// │   - Strong peak at expected angle, zero elsewhere (ideal grating)      │
// │   - Different wavelengths have different peak angles (dispersion)      │
// │                                                                         ║
// │ Dispersion Examples:                                                    ║
// │   - Red (650nm):   sin⁻¹(m×650/d) → larger angle                      │
// │   - Green (550nm): sin⁻¹(m×550/d) → medium angle                      │
// │   - Blue (450nm):  sin⁻¹(m×450/d) → smaller angle                     │
// │   - Creates wavelength separation (rainbow/spectrum effect)             │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Spectral bloom (wavelength-dependent light dispersion)             │
// │   - Simulated prism/rainbow effects                                    │
// │   - Chromatic aberration simulation                                    │
// └─────────────────────────────────────────────────────────────────────────┘
float diffractionGrating(
    float angle,
    float gratingSpacing,
    float wavelengthNorm,
    int order
) {
    // ────────────────────────────────────────────────────────────────────────
    // Apply grating equation to find expected angle for wavelength at order
    // Expected angle = arcsin(m × λ / d)
    // ────────────────────────────────────────────────────────────────────────
    float expectedAngle = asin(float(order) * wavelengthNorm / gratingSpacing);

    // ────────────────────────────────────────────────────────────────────────
    // Compute distance from expected angle (Gaussian peak for smooth rendering)
    // Very narrow peak approximates ideal diffraction grating behavior
    // ────────────────────────────────────────────────────────────────────────
    float angleDiff = abs(angle - expectedAngle);
    float peakWidth = 0.01;  // Narrow spectral line for crisp colors

    // ────────────────────────────────────────────────────────────────────────
    // Gaussian envelope gives smooth peak around expected angle
    // Exp(-(Δθ)² / w²) produces natural spectral line shape
    // ────────────────────────────────────────────────────────────────────────
    return exp(-(angleDiff * angleDiff) / (peakWidth * peakWidth));
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECTRAL DECOMPOSITION                                                   ║
// ║                                                                           ║
// │ Maps wavelengths to visible colors and computes spectral responses    │
// │ using diffraction grating equation. Converts wavelength to RGB for    │
// │ rendering iridescent and dispersive effects.                          │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ wavelengthToColor()                                                     ║
// ║                                                                         ║
// │ Maps single wavelength value to RGB color in visible spectrum.        │
// │ Uses smooth transitions through visible wavelengths (violet → red).   │
// │ Produces perceptually smooth color gradients.                         │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   wavelength - Normalized wavelength (0-1 scale)                      │
// │               Typically maps to 380nm-750nm range:                    │
// │               0.00 → Ultraviolet (invisible)                          │
// │               0.25 → Violet (380nm)                                   │
// │               0.35 → Blue (450nm)                                     │
// │               0.50 → Green (550nm)                                    │
// │               0.60 → Yellow (590nm)                                   │
// │               0.75 → Red (700nm)                                      │
// │               1.00 → Infrared (invisible)                             │
// │                                                                         ║
// │ Returns: RGB color [0,1] for given wavelength                        │
// │                                                                         ║
// │ Spectrum Regions:                                                       ║
// │   Violet (0.00-0.25): 380-420nm - dark purple to bright blue         │
// │   Blue (0.25-0.35): 420-495nm - bright blue to cyan                  │
// │   Cyan-Green (0.35-0.50): 495-570nm - cyan through green            │
// │   Yellow (0.50-0.60): 570-590nm - green to yellow                    │
// │   Orange-Red (0.60-0.75): 590-700nm - yellow to red                  │
// │   Deep Red (0.75-1.00): >700nm - dark red to infrared                │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 wavelengthToColor(float wavelength) {
    vec3 color = vec3(0.0);

    // ────────────────────────────────────────────────────────────────────────
    // Map normalized wavelength to RGB color through visible spectrum
    // Uses piecewise linear interpolation in RGB space
    // ────────────────────────────────────────────────────────────────────────

    if (wavelength < 0.25) {
        // ────────────────────────────────────────────────────────────────────
        // Violet region (380-420nm): dark purple → bright blue
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.5, 0.0, 1.0), vec3(0.0, 0.0, 1.0), wavelength / 0.25);
    } else if (wavelength < 0.35) {
        // ────────────────────────────────────────────────────────────────────
        // Blue region (420-495nm): bright blue → cyan
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 0.5, 1.0), (wavelength - 0.25) / 0.1);
    } else if (wavelength < 0.5) {
        // ────────────────────────────────────────────────────────────────────
        // Cyan-Green transition (495-570nm): cyan → green
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.0, 0.5, 1.0), vec3(0.0, 1.0, 0.0), (wavelength - 0.35) / 0.15);
    } else if (wavelength < 0.6) {
        // ────────────────────────────────────────────────────────────────────
        // Yellow region (570-590nm): green → yellow
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0), (wavelength - 0.5) / 0.1);
    } else if (wavelength < 0.75) {
        // ────────────────────────────────────────────────────────────────────
        // Orange-Red region (590-700nm): yellow → red
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), (wavelength - 0.6) / 0.15);
    } else {
        // ────────────────────────────────────────────────────────────────────
        // Deep Red (700nm+): infrared (dark red in rendering)
        // ────────────────────────────────────────────────────────────────────
        color = vec3(1.0, 0.0, 0.0);
    }

    return color;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ spectralResponse()                                                      ║
// ║                                                                         ║
// │ Computes full spectral response for given viewing angle using         │
// │ diffraction grating for each wavelength. Produces wavelength-         │
// │ dependent color response typical of dispersion effects (spectrum).    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle           - Observation angle (radians)                        │
// │   wavelengthMin   - Minimum wavelength (typically 0.0)                │
// │   wavelengthMax   - Maximum wavelength (typically 1.0)                │
// │                                                                         ║
// │ Returns: RGB [0,1] - Combined spectral response at angle             │
// │                                                                         ║
// │ Algorithm:                                                              ║
// │   1. Sample RGB wavelengths: Red (650nm), Green (550nm), Blue (450nm)│
// │   2. For each order (-2 to +2): apply grating equation               │
// │   3. Each wavelength peaks at different angle (dispersion)            │
// │   4. Red peaks at largest angle, blue at smallest                    │
// │   5. Combine: if angle matches red peak → strong R, weak B           │
// │              if angle matches blue peak → strong B, weak R            │
// │                                                                         ║
// │ Output Characteristics:                                                │
// │   - At small angle: blue/violet dominates                            │
// │   - At medium angle: green/yellow dominates                          │
// │   - At large angle: red dominates                                    │
// │   - Like a prism separating light into spectrum                       │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 spectralResponse(float angle, float wavelengthMin, float wavelengthMax) {
    // ────────────────────────────────────────────────────────────────────────
    // Accumulate grating response across multiple diffraction orders
    // ────────────────────────────────────────────────────────────────────────
    vec3 color = vec3(0.0);

    // ────────────────────────────────────────────────────────────────────────
    // Scan diffraction orders from -2 to +2 (multiple spectrum repetitions)
    // Order 0 = central undiffracted beam
    // Orders ±1 = first spectrum, ±2 = second spectrum (dimmer)
    // ────────────────────────────────────────────────────────────────────────
    for (int order = -2; order <= 2; order++) {
        // ────────────────────────────────────────────────────────────────────
        // RGB wavelengths (normalized to 0-1)
        // Red: 650nm, Green: 550nm, Blue: 450nm
        // ────────────────────────────────────────────────────────────────────
        vec3 wavelengths = vec3(650.0, 550.0, 450.0) / 1000.0;

        // ────────────────────────────────────────────────────────────────────
        // Evaluate diffraction grating for each RGB wavelength at this order
        // Each wavelength produces peak at different angle
        // ────────────────────────────────────────────────────────────────────
        for (int ch = 0; ch < 3; ch++) {
            float w = (ch == 0) ? wavelengths.r : ((ch == 1) ? wavelengths.g : wavelengths.b);
            float grating = diffractionGrating(angle, 0.1, w, order);

            // Accumulate grating response into appropriate channel
            if (ch == 0) color.r += grating;
            else if (ch == 1) color.g += grating;
            else color.b += grating;
        }
    }

    // ────────────────────────────────────────────────────────────────────────
    // Normalize by number of orders sampled (5 orders total: -2,-1,0,+1,+2)
    // Results in final RGB color showing which wavelengths peak at angle
    // ────────────────────────────────────────────────────────────────────────
    return color / 3.0;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ CHROMATIC ABERRATION FROM DIFFRACTION                                    ║
// ║                                                                           ║
// │ Simulates lens chromatic aberration: wavelength-dependent refraction   │
// │ through optical elements. Produces color fringing at edges of bright   │
// │ objects (red outward, blue inward, or vice versa depending on lens).   │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ chromaticAberration()                                                   ║
// ║                                                                         ║
// │ Computes per-channel chromatic aberration offsets for lens dispersion. │
// │ Different wavelengths refract at slightly different angles - causes    │
// │ RGB channels to misalign on screen, especially toward image edges.     │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord  - Current screen position                              │
// │   centerCoord  - Image center or lens center                          │
// │   strength     - Aberration magnitude (0=none, 1=strong)              │
// │                                                                         ║
// │ Returns: Offset magnitude for each channel (R,G,B)                    │
// │   High precision offset: tells shader where to sample each channel     │
// │   Typically applied by shifting texture sample position per channel    │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Caused by wavelength-dependent refractive index: n(λ)             │
// │   - Shorter wavelengths (blue) refract more than longer (red)         │
// │   - Radial position determines aberration magnitude (edges worse)      │
// │   - Typical lens: |n(blue) - n(red)| ≈ 0.01-0.02                     │
// │                                                                         ║
// │ Visual Effect:                                                          ║
// │   - Red fringe on one side, cyan fringe on opposite                   │
// │   - More pronounced away from image center                            │
// │   - Can be positive (red outward) or negative (depends on lens)       │
// │   - Controllable for realism or stylistic effect                      │
// │                                                                         ║
// │ Implementation Notes:                                                  │
// │   - Red: 2% shift (least refraction)                                  │
// │   - Green: 1% shift (medium refraction)                               │
// │   - Blue: 3% shift (most refraction)                                  │
// │   - Multiply by strength and radial distance for realistic effect     │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 chromaticAberration(vec2 screenCoord, vec2 centerCoord, float strength) {
    // ────────────────────────────────────────────────────────────────────────
    // Direction from image center to current pixel (radial direction)
    // Aberration is strongest radially outward
    // ────────────────────────────────────────────────────────────────────────
    vec2 dir = normalize(screenCoord - centerCoord);
    float dist = length(screenCoord - centerCoord);

    // ────────────────────────────────────────────────────────────────────────
    // Wavelength-dependent offset multipliers
    // Red light bends least (shorter focal length adjustment)
    // Blue light bends most (longer focal length adjustment)
    // Percentage shifts are typical for real camera lenses
    // ────────────────────────────────────────────────────────────────────────
    // Red offset: 2% (typical 650nm)
    vec2 offsetR = centerCoord + dir * (dist * (1.0 - strength * 0.02));
    // Green offset: 1% (typical 550nm)
    vec2 offsetG = centerCoord + dir * (dist * (1.0 - strength * 0.01));
    // Blue offset: 3% (typical 450nm)
    vec2 offsetB = centerCoord + dir * (dist * (1.0 - strength * 0.03));

    // ────────────────────────────────────────────────────────────────────────
    // Return magnitude of shift for each channel (for texture sampling offset)
    // These are used to sample R, G, B from different positions
    // ────────────────────────────────────────────────────────────────────────
    return vec3(length(offsetR - screenCoord), length(offsetG - screenCoord), length(offsetB - screenCoord));
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ AIRY DISK DIFFRACTION                                                    ║
// ║                                                                           ║
// │ Circular aperture diffraction patterns: Airy disk (bright central     │
// │ disk) surrounded by concentric rings of decreasing intensity. Classic  │
// │ point spread function for circular optical systems.                    │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ airyDisk()                                                              ║
// ║                                                                         ║
// │ Computes Airy diffraction pattern from circular aperture. Produces    │
// │ characteristic bright disk surrounded by dimmer rings.                │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord         - Screen position                               │
// │   centerCoord         - Aperture/light center                         │
// │   apertureDiameter    - Aperture opening diameter (normalized 0-1)    │
// │   wavelength          - Light wavelength (normalized 0-1)             │
// │                                                                         ║
// │ Returns: Intensity [0,1] from Airy pattern                           │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Airy pattern: I(r) = [2×J₁(x)/x]²                               │
// │   - x = π × D × r / (f × λ) (Fresnel parameter)                    │
// │   - D = aperture diameter, r = radius, f = focal length, λ = wavelength
// │   - Central disk (primary lobe): brightest peak at r=0              │
// │   - First dark ring: x ≈ 3.83 (where J₁(x)=0)                       │
// │   - First bright ring: x ≈ 5.14 (secondary maximum)                  │
// │   - Intensity drops rapidly with radius (∝ 1/r² beyond first ring)   │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Point light bloom with realistic diffraction shape                │
// │   - Sun disk rendering with halo                                     │
// │   - Depth of field point spread function                             │
// └─────────────────────────────────────────────────────────────────────────┘
float airyDisk(vec2 screenCoord, vec2 centerCoord, float apertureDiameter, float wavelength) {
    vec2 delta = screenCoord - centerCoord;
    float radius = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Airy pattern parameter: x = π × D × r / (f × λ)
    // Controls number and spacing of rings
    // ────────────────────────────────────────────────────────────────────────
    float x = 3.14159265359 * apertureDiameter * radius / wavelength;

    // ────────────────────────────────────────────────────────────────────────
    // Handle singularity at center (r=0 → x→0)
    // ────────────────────────────────────────────────────────────────────────
    if (x < 0.001) return 1.0;

    // ────────────────────────────────────────────────────────────────────────
    // Bessel J₁ function approximation
    // Different formulas for small (x<8) and large (x≥8) arguments
    // ────────────────────────────────────────────────────────────────────────
    float j1;
    if (x < 8.0) {
        // Direct approximation for small arguments (most common case)
        j1 = sin(x) / (x * x) - cos(x) / x;
    } else {
        // Asymptotic approximation for large arguments
        j1 = sqrt(2.0 / (3.14159265359 * x)) * sin(x - 3.0 * 3.14159265359 / 4.0);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Airy intensity formula: I = [2×J₁(x)/x]²
    // ────────────────────────────────────────────────────────────────────────
    float airy = 2.0 * j1 / x;
    return airy * airy;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ diffractospike()                                                        ║
// ║                                                                         ║
// │ Creates diffraction spike pattern from polygonal aperture. Used for    │
// │ star-like patterns in lens flares and point light blooms.             │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenCoord  - Screen position                                      │
// │   centerCoord  - Light source center                                  │
// │   wavelength   - Light wavelength (affects ring spacing, unused here) │
// │   spikes       - Number of spikes (typically 4, 6, or 8)             │
// │                                                                         ║
// │ Returns: Spike intensity [0,1]                                        │
// │                                                                         ║
// │ Geometry:                                                               ║
// │   - n spikes: regular polygon aperture with n sides                  │
// │   - Spikes aligned radially from center                              │
// │   - Spike angle spacing: 180°/n (e.g., 6 spikes = 30° apart)        │
// │   - Narrow spikes converge at center for crisp star effect           │
// │                                                                         ║
// │ Intensity Control:                                                      ║
// │   - Gaussian spike: narrow peak for sharpness                        │
// │   - Radial falloff: stronger near center, fades outward              │
// │   - Result: thin rays emanating from light source                    │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Telescope/mirror diffraction spikes                              │
// │   - Stylized lens flares                                             │
// │   - Point light and sun rendering                                    │
// └─────────────────────────────────────────────────────────────────────────┘
float diffractospike(vec2 screenCoord, vec2 centerCoord, float wavelength, int spikes) {
    vec2 delta = screenCoord - centerCoord;
    float angle = atan(delta.y, delta.x);
    float radius = length(delta);

    // ────────────────────────────────────────────────────────────────────────
    // Compute angular spacing between spikes
    // n spikes → spacing of π/n radians (180°/n degrees)
    // ────────────────────────────────────────────────────────────────────────
    float spikeAngleStep = 3.14159265359 / float(spikes);

    // ────────────────────────────────────────────────────────────────────────
    // Find angle to nearest spike
    // Uses modulo to wrap angle into [0, spikeAngleStep]
    // Then measures distance to spike center (spikeAngleStep/2)
    // ────────────────────────────────────────────────────────────────────────
    float angleToNearest = abs(mod(angle, spikeAngleStep) - spikeAngleStep * 0.5);

    // ────────────────────────────────────────────────────────────────────────
    // Gaussian spike profile (narrow gaussian for crisp spikes)
    // Exponential falloff with angle distance creates narrow rays
    // ────────────────────────────────────────────────────────────────────────
    float spike = exp(-(angleToNearest * angleToNearest) / 0.01);

    // ────────────────────────────────────────────────────────────────────────
    // Radial falloff: spikes fade with distance from center
    // 1/(1 + r²×0.1) produces natural falloff
    // ────────────────────────────────────────────────────────────────────────
    float falloff = 1.0 / (1.0 + radius * radius * 0.1);

    return spike * falloff;
}

#endif // INCLUDE_DIFFRACTION
