// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║                  COMPLEX WATER PHYSICS (PHASE 18)                        ║
// ║                                                                           ║
// ║  Hierarchical Gerstner wave system for realistic water surfaces.        ║
// ║  Proper phase relationships, energy conservation, and multi-scale        ║
// ║  wave interaction. Gerstner waves produce peaked crests and broad       ║
// ║  troughs characteristic of real ocean dynamics.                         ║
// ║                                                                           ║
// ║  References: Mastin et al. 2005, Gonzato et al. 2002, Tessendorf 2004  ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_WATER_PHYSICS
#define INCLUDE_WATER_PHYSICS

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ GERSTNER WAVE DEFINITION                                                 ║
// ║                                                                           ║
// │ Single Gerstner wave component with wavelength, amplitude, speed,      │
// │ direction, and animation phase. Gerstner waves produce realistic       │
// │ cycloid particle motion creating characteristic wave shapes.           │
// └───────────────────────────────────────────────────────────────────────────┘

struct GerstnerWave {
    float wavelength;      // Distance between crests (normalized)
    float amplitude;       // Wave height magnitude
    float speed;           // Propagation speed
    vec2 direction;        // Propagation direction (normalized)
    float phase;           // Animation phase offset
};

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ WAVE CALCULATION                                                         ║
// │                                                                           ║
// │ Computes surface displacement and normals from Gerstner wave equation. │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gerstnerWaveDisplacement()                                              ║
// ║                                                                         ║
// │ Computes 3D displacement from single Gerstner wave using cycloid      │
// │ motion formula. Each water particle traces elliptical path as wave    │
// │ passes, creating realistic peaked crests and broad troughs.           │
// │                                                                         ║
// │ Formula: x' = x - A×(k/ω)×sin(φ)×dir.x                             │
// │          z' = z - A×(k/ω)×sin(φ)×dir.y                             │
// │          y' = y + A×cos(φ)                                           │
// │ Where: k=2π/λ (wavenumber), ω=k×speed (angular frequency), φ=phase  │
// │                                                                         ║
// │ Returns: 3D displacement vector (XZ horizontal, Y vertical)           │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 gerstnerWaveDisplacement(
    vec3 worldPosition,
    GerstnerWave wave,
    float time
) {
    // ────────────────────────────────────────────────────────────────────────
    // Wave equation parameters
    // k = wavenumber (spatial frequency), ω = angular frequency (temporal)
    // ────────────────────────────────────────────────────────────────────────
    float k = 2.0 * 3.14159265359 / wave.wavelength;
    float w = k * wave.speed;

    // ────────────────────────────────────────────────────────────────────────
    // Compute phase: spatial + temporal components
    // φ = k·d - ω·t + phase_offset
    // ────────────────────────────────────────────────────────────────────────
    float d = dot(worldPosition.xz, wave.direction);
    float phase = k * d - w * time + wave.phase;

    // ────────────────────────────────────────────────────────────────────────
    // Gerstner wave displacement (cycloid motion)
    // Horizontal: circles traced by particles as wave passes
    // Vertical: up/down motion synchronized with horizontal
    // ────────────────────────────────────────────────────────────────────────
    float amplitude_factor = wave.amplitude * k / w;

    vec3 displacement = vec3(0.0);
    displacement.xz = -amplitude_factor * sin(phase) * wave.direction;
    displacement.y = wave.amplitude * cos(phase);

    return displacement;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ gerstnerWaveNormal()                                                    ║
// ║                                                                         ║
// │ Computes surface normal from wave displacement using finite           │
// │ differences. Samples displacement at 3 points, computes tangent      │
// │ vectors, and takes cross product for normal direction.               │
// │                                                                         ║
// │ Returns: Normalized surface normal for lighting calculations         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 gerstnerWaveNormal(
    vec3 worldPosition,
    GerstnerWave wave,
    float time,
    float sampleDistance
) {
    // ────────────────────────────────────────────────────────────────────────
    // Finite difference sampling: displacements at 3 grid points
    // ────────────────────────────────────────────────────────────────────────
    vec3 disp = gerstnerWaveDisplacement(worldPosition, wave, time);
    vec3 disp_x = gerstnerWaveDisplacement(worldPosition + vec3(sampleDistance, 0.0, 0.0), wave, time);
    vec3 disp_z = gerstnerWaveDisplacement(worldPosition + vec3(0.0, 0.0, sampleDistance), wave, time);

    // ────────────────────────────────────────────────────────────────────────
    // Compute tangent vectors from displacement gradients
    // ∂p/∂x, ∂p/∂z directions on surface
    // ────────────────────────────────────────────────────────────────────────
    vec3 tangentX = vec3(1.0, (disp_x.y - disp.y) / sampleDistance, 0.0);
    vec3 tangentZ = vec3(0.0, (disp_z.y - disp.y) / sampleDistance, 1.0);

    // ────────────────────────────────────────────────────────────────────────
    // Normal = cross(∂p/∂z, ∂p/∂x) normalized
    // ────────────────────────────────────────────────────────────────────────
    return normalize(cross(tangentZ, tangentX));
}

// ===================================================================
// HIERARCHICAL WAVE SYSTEM
// ===================================================================

// Define wave spectrum with multiple scales
const int MAX_WAVES = 8;

struct WaveSpectrum {
    GerstnerWave waves[MAX_WAVES];
    int waveCount;
};

// Initialize wave spectrum (ocean-like parameters)
WaveSpectrum initializeWaveSpectrum(float time) {
    WaveSpectrum spectrum;
    spectrum.waveCount = 0;

    // Large waves (dominant)
    spectrum.waves[0] = GerstnerWave(
        20.0,                                // Wavelength
        1.2,                                 // Amplitude
        10.0,                                // Speed
        normalize(vec2(1.0, 0.3)),          // Direction
        0.0                                  // Phase
    );
    spectrum.waveCount++;

    // Medium waves (secondary)
    spectrum.waves[1] = GerstnerWave(
        12.0,
        0.6,
        8.0,
        normalize(vec2(0.5, 0.9)),
        1.5
    );
    spectrum.waveCount++;

    // Small waves (detail)
    spectrum.waves[2] = GerstnerWave(
        5.0,
        0.3,
        4.0,
        normalize(vec2(0.1, -0.95)),
        3.0
    );
    spectrum.waveCount++;

    // Fine detail waves
    spectrum.waves[3] = GerstnerWave(
        2.0,
        0.1,
        2.0,
        normalize(vec2(0.8, -0.6)),
        5.0
    );
    spectrum.waveCount++;

    return spectrum;
}

// Compute total displacement from wave spectrum
vec3 computeWaveDisplacement(
    vec3 worldPosition,
    WaveSpectrum spectrum,
    float time
) {
    vec3 totalDisplacement = vec3(0.0);

    for (int i = 0; i < MAX_WAVES && i < spectrum.waveCount; i++) {
        totalDisplacement += gerstnerWaveDisplacement(worldPosition, spectrum.waves[i], time);
    }

    return totalDisplacement;
}

// Compute normal from all waves
vec3 computeWaveNormal(
    vec3 worldPosition,
    WaveSpectrum spectrum,
    float time
) {
    vec3 normal = vec3(0.0, 1.0, 0.0);

    for (int i = 0; i < MAX_WAVES && i < spectrum.waveCount; i++) {
        vec3 waveNormal = gerstnerWaveNormal(worldPosition, spectrum.waves[i], time, 0.5);
        normal = normalize(normal + waveNormal * 0.5);  // Blend normals
    }

    return normal;
}

// ===================================================================
// WAVE STATISTICS
// ===================================================================

// Compute maximum wave height at position
float computeMaxWaveHeight(WaveSpectrum spectrum) {
    float maxHeight = 0.0;

    for (int i = 0; i < MAX_WAVES && i < spectrum.waveCount; i++) {
        maxHeight += spectrum.waves[i].amplitude;
    }

    return maxHeight;
}

// Estimate wave steepness (amplitude / wavelength)
float computeWaveSteepness(GerstnerWave wave) {
    return wave.amplitude / wave.wavelength;
}

// Check if wave is breaking (steepness > critical angle)
bool isWaveBreaking(GerstnerWave wave) {
    float steepness = computeWaveSteepness(wave);
    return steepness > 0.3;  // Critical steepness threshold
}

// ===================================================================
// WAVE INTERACTION
// ===================================================================

// Compute wave foam based on curvature (high curvature = breaking)
float computeWaveFoamIntensity(
    vec3 worldPosition,
    WaveSpectrum spectrum,
    float time
) {
    float foamIntensity = 0.0;

    for (int i = 0; i < MAX_WAVES && i < spectrum.waveCount; i++) {
        GerstnerWave wave = spectrum.waves[i];

        // Check if wave is breaking
        if (isWaveBreaking(wave)) {
            float k = 2.0 * 3.14159265359 / wave.wavelength;
            float w = k * wave.speed;
            float d = dot(worldPosition.xz, wave.direction);
            float phase = k * d - w * time + wave.phase;

            // Curvature is second derivative of height
            float curvature = -wave.amplitude * k * cos(phase);

            // Foam from high positive curvature (crest region)
            if (curvature > 0.5) {
                foamIntensity += (curvature - 0.5) * 0.5;
            }
        }
    }

    return clamp(foamIntensity, 0.0, 1.0);
}

// ===================================================================
// SHALLOW WATER EFFECTS
// ===================================================================

// Modify waves based on water depth (waves slow and steepen in shallow water)
vec3 shallowWaterWaveDisplacement(
    vec3 worldPosition,
    WaveSpectrum spectrum,
    float time,
    float waterDepth
) {
    vec3 displacement = computeWaveDisplacement(worldPosition, spectrum, time);

    // Shallow water effects: waves slow and amplify
    float depthFactor = clamp(waterDepth / 10.0, 0.0, 1.0);

    // Slow down waves in shallow water
    displacement *= mix(1.0, 0.5, 1.0 - depthFactor);

    // Amplify in shallow water (wave height increases as wavelength decreases)
    displacement *= mix(1.5, 1.0, depthFactor);

    return displacement;
}

#endif // INCLUDE_WATER_PHYSICS
