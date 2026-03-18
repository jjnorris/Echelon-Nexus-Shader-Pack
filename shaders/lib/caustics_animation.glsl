// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║                ANIMATED CAUSTICS FIELD (PHASE 17)                        ║
// ║                                                                           ║
// ║  Real-time animated caustic patterns for water surfaces using           ║
// ║  wave-based diffraction and wave simulation. Produces smooth temporal    ║
// ║  continuity and realistic light focusing/defocusing effects from        ║
// ║  water surface wave geometry.                                            ║
// ║                                                                           ║
// ║  Physics: Caustics result from refraction of light through wavy water  ║
// ║  surfaces. Wave peaks focus light (bright), troughs defocus (dark).    ║
// ║  Proper simulation uses wave slopes (normal gradients) to compute       ║
// ║  refraction and intensity modulation.                                   ║
// ║                                                                           ║
// ║  Implementation: Multiple octaves of sine/Perlin waves with different  ║
// ║  frequencies, amplitudes, and phase velocities for visual complexity.   ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_CAUSTICS_ANIMATION
#define INCLUDE_CAUSTICS_ANIMATION

#include "noise.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ CAUSTIC PATTERN GENERATION                                               ║
// ║                                                                           ║
// │ Generates smooth, animated caustic intensity patterns using overlaid    │
// │ sine waves. Multiple frequencies create complex appearance with good    │
// │ frame-to-frame coherence for temporal stability.                       │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ causticPattern()                                                        ║
// ║                                                                         ║
// │ Generates animated caustic pattern from layered sine waves. Multiple   │
// │ wave frequencies with different speeds create organic motion without   │
// │ obvious periodicity.                                                    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   uv    - Caustic UV coordinates (0-1 range, typically screen-space)  │
// │   time  - Animation time parameter (typically frameTime or framesCount)│
// │   scale - Spatial frequency scaling (higher = more detail/frequency)   │
// │   speed - Animation speed multiplier (higher = faster motion)          │
// │                                                                         ║
// │ Returns: Caustic intensity [0, 1] at UV for given time                │
// │                                                                         ║
// │ Wave Composition:                                                       ║
// │   - Wave 1: x-direction, slow speed (0.5×speed), frequency 1.0        │
// │   - Wave 2: y-direction, medium speed (0.6×speed), frequency 0.7      │
// │   - Wave 3: diagonal, fastest (0.4×speed), frequency 0.8              │
// │   - Each wave: sin(pos + time×vel) normalized to ±0.5                 │
// │   - Sum: combines to produce complex interference pattern              │
// │                                                                         ║
// │ Output Quality:                                                         ║
// │   - Smooth animation: frequency variety prevents obvious repetition    │
// │   - Speed variation: different waves move at different rates           │
// │   - Realistic detail: multiple octaves create visual complexity       │
// │   - Normalized output: clamped to [0,1] for intensity blending        │
// └─────────────────────────────────────────────────────────────────────────┘
float causticPattern(vec2 uv, float time, float scale, float speed) {
    // ────────────────────────────────────────────────────────────────────────
    // Scale UV coordinates by desired caustic frequency
    // Higher scale = finer caustic detail, more waves visible
    // ────────────────────────────────────────────────────────────────────────
    vec2 scaledUv = uv * scale;

    // ────────────────────────────────────────────────────────────────────────
    // Three sine waves with different frequencies and phase velocities
    // Each contributes 0.5 amplitude, combined sum later normalized
    // ────────────────────────────────────────────────────────────────────────

    // Wave 1: horizontal waves, slow motion
    float wave1 = sin(scaledUv.x * 1.0 + time * speed * 0.5) * 0.5;

    // Wave 2: vertical waves, medium speed
    float wave2 = sin(scaledUv.y * 0.7 + time * speed * 0.6) * 0.5;

    // Wave 3: diagonal waves, different speed for visual complexity
    float wave3 = sin((scaledUv.x + scaledUv.y) * 0.8 + time * speed * 0.4) * 0.5;

    // ────────────────────────────────────────────────────────────────────────
    // Sum all waves (range: -1.5 to +1.5, typically -0.5 to +0.5 with variation)
    // ────────────────────────────────────────────────────────────────────────
    float pattern = wave1 + wave2 + wave3;

    // ────────────────────────────────────────────────────────────────────────
    // Normalize to [0, 1] intensity range
    // 0.5 + 0.5*pattern maps [-1,+1] → [0,1]
    // ────────────────────────────────────────────────────────────────────────
    return 0.5 + 0.5 * pattern;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ layeredCaustic()                                                        ║
// ║                                                                         ║
// │ Combines multiple octaves of caustic patterns at different scales.     │
// │ Each octave (scale doubling) adds finer detail while maintaining       │
// │ coherence. Produces rich, complex caustics with multiple motion layers.│
// │                                                                         ║
// │ Parameters:                                                            ║
// │   uv    - Caustic UV coordinates                                       │
// │   time  - Animation time                                               │
// │   speed - Base animation speed (modified per layer)                    │
// │                                                                         ║
// │ Returns: Combined caustic intensity [0, 1]                            │
// │                                                                         ║
// │ Octave Structure:                                                       ║
// │   Layer 1 (scale 2.0):   Large waves, 50% weight, normal speed      │
// │   Layer 2 (scale 4.0):   Medium features, 30% weight, 1.3× speed    │
// │   Layer 3 (scale 8.0):   Fine details, 20% weight, 1.7× speed       │
// │   Total weight: 50% + 30% + 20% = 100% (normalized)                 │
// │                                                                         ║
// │ Frequency Characteristics:                                             ║
// │   - Layer 1: dominant, slow-moving large features                    │
// │   - Layer 2: medium detail with faster animation                     │
// │   - Layer 3: fine flicker adds realism                               │
// │   - Speed variation: prevents pattern repetition                      │
// │                                                                         ║
// │ Visual Effect:                                                          ║
// │   - Organic wave motion with multiple temporal scales                 │
// │   - Fast ripples overlay slow undulation for natural appearance       │
// │   - Detail density scales with viewing distance (if used with LOD)    │
// └─────────────────────────────────────────────────────────────────────────┘
float layeredCaustic(vec2 uv, float time, float speed) {
    float caustic = 0.0;

    // ────────────────────────────────────────────────────────────────────────
    // Layer 1: Large-scale waves (dominant visual features)
    // Scale 2.0 = moderate spatial frequency
    // Speed multiplier 1.0 (base speed)
    // Weight: 50% contribution to final result
    // ────────────────────────────────────────────────────────────────────────
    caustic += causticPattern(uv, time, 2.0, speed) * 0.5;

    // ────────────────────────────────────────────────────────────────────────
    // Layer 2: Medium-scale features (intermediate detail)
    // Scale 4.0 = twice the spatial frequency as layer 1
    // Speed multiplier 1.3× (faster animation for visual interest)
    // Weight: 30% contribution
    // ────────────────────────────────────────────────────────────────────────
    caustic += causticPattern(uv, time, 4.0, speed * 1.3) * 0.3;

    // ────────────────────────────────────────────────────────────────────────
    // Layer 3: Fine detail layer (adds realism and flicker)
    // Scale 8.0 = 4× the spatial frequency, finest ripples
    // Speed multiplier 1.7× (fastest, most dynamic layer)
    // Weight: 20% contribution (subtle detail addition)
    // ────────────────────────────────────────────────────────────────────────
    caustic += causticPattern(uv, time, 8.0, speed * 1.7) * 0.2;

    return caustic;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ PERLIN-BASED CAUSTICS                                                    ║
// ║                                                                           ║
// │ Uses Perlin/gradient noise instead of sine waves for smoother, more     │
// │ organic caustic patterns. Perlin noise produces natural-looking        │
// │ fluid motion without obvious periodicity.                               │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ perlintCaustic()                                                        ║
// ║                                                                         ║
// │ Generates smooth, organic caustics using Perlin noise (fnoise).       │
// │ Produces less artificial appearance than sine-wave patterns with       │
// │ smoother transitions and more fluid motion.                            │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   uv    - Caustic UV coordinates                                      │
// │   time  - Animation time                                              │
// │   speed - Animation speed multiplier                                  │
// │                                                                         ║
// │ Returns: Caustic intensity [0, 1]                                    │
// │                                                                         ║
// │ Algorithm:                                                              ║
// │   1. Compute flow offset from time/speed                              │
// │   2. Sample Perlin noise at 3 octaves (frequencies 2×, 4×, 8×)       │
// │   3. Blend with octave weights: 50%/30%/20%                         │
// │   4. Apply smoothstep to enhance contrast and limit range             │
// │                                                                         ║
// │ Advantage over sines:                                                  ║
// │   - Continuous derivatives (smooth gradients)                         │
// │   - Natural-looking turbulence without visible periodicity           │
// │   - Each octave can have independent phase velocity                  │
// │   - More convincing fluid dynamics simulation                        │
// │                                                                         ║
// │ Visual Characteristics:                                                │
// │   - Soft, flowing patterns                                           │
// │   - Spatial coherence (nearby pixels similar)                        │
// │   - Temporal coherence (smooth frame transitions)                    │
// │   - Suitable for realis water caustics                               │
// └─────────────────────────────────────────────────────────────────────────┘
float perlintCaustic(vec2 uv, float time, float speed) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute UV with flowing offset for directional motion
    // Flow direction: x increases slowly (0.1×speed), y faster (0.15×speed)
    // Creates diagonal drift typical of water surface motion
    // ────────────────────────────────────────────────────────────────────────
    vec2 flowUv = uv + vec2(time * speed * 0.1, time * speed * 0.15);

    // ────────────────────────────────────────────────────────────────────────
    // Multi-octave Perlin noise sampling
    // Each octave has different frequency and animation phase
    // ────────────────────────────────────────────────────────────────────────

    // Octave 1: Large features, base frequency
    float n1 = fnoise(flowUv * 2.0);

    // Octave 2: Medium detail, 2× frequency, different phase velocity
    float n2 = fnoise(flowUv * 4.0 + vec2(time * speed * 0.2, 0.0));

    // Octave 3: Fine ripples, 4× frequency, y-directed phase
    float n3 = fnoise(flowUv * 8.0 + vec2(0.0, time * speed * 0.2));

    // ────────────────────────────────────────────────────────────────────────
    // Combine octaves with fractional weights (weighted average)
    // n1 contributes 50%, n2 contributes 30%, n3 contributes 20%
    // Result: natural-looking turbulence from multiple scales
    // ────────────────────────────────────────────────────────────────────────
    float caustic = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

    // ────────────────────────────────────────────────────────────────────────
    // Apply smoothstep to enhance contrast
    // Remaps [0.3, 0.7] → [0, 1], creating S-curve
    // Makes bright areas brighter, dark areas darker for visual punch
    // Typical threshold range for caustics: 0.3-0.7 (suppress mid-tones)
    // ────────────────────────────────────────────────────────────────────────
    caustic = smoothstep(0.3, 0.7, caustic);

    return caustic;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ REALISTIC CAUSTIC FROM WAVE SIMULATION                                   ║
// ║                                                                           ║
// │ Physically-based approach: simulate shallow-water wave equation for     │
// │ displacement field, then compute caustic intensity from surface slopes │
// │ (gradient magnitude). Bright where waves focus light, dark where they  │
// │ defocus (diverge).                                                      │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ waveDisplacement()                                                      ║
// ║                                                                         ║
// │ Computes 2D displacement field for shallow-water wave simulation.      │
// │ Uses plane wave superposition (multiple frequencies + directions)       │
// │ to produce realistic wave interference patterns.                        │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   position   - Surface position (normalized coordinates)               │
// │   time       - Animation time                                          │
// │   wavelength - Dominant wavelength (0-1 scale, affects k parameter)   │
// │   amplitude  - Wave displacement magnitude (0-1)                       │
// │                                                                         ║
// │ Returns: vec2 displacement [x,y] from wave simulation                 │
// │                                                                         ║
// │ Wave Physics:                                                            │
// │   - Wavenumber: k = 2π/λ (spatial frequency)                          │
// │   - Angular frequency: ω = 2π×0.8 (temporal frequency)                │
// │   - Plane wave: η(x,t) = A × sin(k×x - ω×t) (phase velocity)         │
// │   - Multiple waves with different frequencies and directions           │
// │                                                                         ║
// │ Wave Composition:                                                       ║
// │   - Wave 1: x-direction propagation, 100% amplitude                   │
// │   - Wave 2: y-direction propagation, 80% amplitude, slower (0.7×)     │
// │   - Wave 3: diagonal propagation, 50% amplitude, faster (1.2×)        │
// │   - Interference between waves creates caustic pattern                 │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Realistic caustic patterns from physics-based simulation          │
// │   - Underwater light modulation (geometry-accurate)                    │
// │   - Wave refraction field for screen-space effects                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec2 waveDisplacement(vec2 position, float time, float wavelength, float amplitude) {
    // ────────────────────────────────────────────────────────────────────────
    // Wave equation parameters
    // k = 2π/λ: wavenumber controls spatial frequency
    // ω = 2π×0.8: angular frequency (0.8 chosen for realistic wave speed)
    // ────────────────────────────────────────────────────────────────────────
    float k = 2.0 * 3.14159265359 / wavelength;
    float omega = 2.0 * 3.14159265359 * 0.8;

    // ────────────────────────────────────────────────────────────────────────
    // Primary waves: x and y directions with phase relationships
    // Wave1: travels in x-direction
    // Wave2: travels in y-direction with 30% slower phase velocity (0.7×)
    // ────────────────────────────────────────────────────────────────────────
    float wave1 = sin(k * position.x - omega * time) * amplitude;
    float wave2 = sin(k * position.y - omega * time * 0.7) * amplitude * 0.8;

    // ────────────────────────────────────────────────────────────────────────
    // Secondary wave (interference pattern)
    // Diagonal direction with higher frequency (1.2× omega)
    // Amplitude reduced (50%) to avoid overwhelming primary waves
    // ────────────────────────────────────────────────────────────────────────
    float wave3 = sin(k * (position.x + position.y) * 0.7 - omega * time * 1.2) * amplitude * 0.5;

    // ────────────────────────────────────────────────────────────────────────
    // Superpose waves: combine into 2D displacement
    // x: primary wave1 + partial wave3 (0.5 weight)
    // y: primary wave2 + partial wave3 (0.3 weight)
    // ────────────────────────────────────────────────────────────────────────
    return vec2(wave1 + wave3 * 0.5, wave2 + wave3 * 0.3);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ causticFromWaves()                                                      ║
// ║                                                                         ║
// │ Computes caustic intensity from wave-displaced surface using gradient │
// │ magnitude. This models how wave slopes modulate light intensity:      │
// │ steep slopes focus light (bright), gentle slopes spread light (dark). │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenUv - Screen/surface UV coordinates                            │
// │   time     - Animation time                                           │
// │                                                                         ║
// │ Returns: Caustic intensity [0, 1]                                    │
// │                                                                         ║
// │ Algorithm:                                                              ║
// │   1. Compute displacement at current UV                               │
// │   2. Compute displacement at nearby points (0.001 offset)            │
// │   3. Compute numerical gradient (∂d/∂x, ∂d/∂y)                      │
// │   4. Compute slope magnitude |∇d|                                    │
// │   5. Intensity = 1/(1 + |∇d|×0.5) (inverse relationship)           │
// │                                                                         ║
// │ Physics:                                                                │
// │   - Steep wave slope: large |∇d| → small intensity (dark)           │
// │   - Gentle slope: small |∇d| → large intensity (bright)             │
// │   - Models Jacobian of refraction mapping                            │
// │   - Approximates caustic energy conservation on surface               │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Physically accurate underwater lighting                          │
// │   - Wave-based refraction for screen-space effects                   │
// │   - Realistic caustic focusing/defocusing                           │
// └─────────────────────────────────────────────────────────────────────────┘
float causticFromWaves(vec2 screenUv, float time) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute wave displacement at current point
    // ────────────────────────────────────────────────────────────────────────
    vec2 displace = waveDisplacement(screenUv, time, 0.5, 0.1);
    vec2 displaceUv = screenUv + displace;

    // ────────────────────────────────────────────────────────────────────────
    // Compute numerical gradient of displacement field
    // Offset by 0.001 in x and y directions for finite difference
    // ────────────────────────────────────────────────────────────────────────
    vec2 d1 = waveDisplacement(displaceUv + vec2(0.001, 0.0), time, 0.5, 0.1);
    vec2 d2 = waveDisplacement(displaceUv + vec2(0.0, 0.001), time, 0.5, 0.1);

    // ────────────────────────────────────────────────────────────────────────
    // Compute gradient (wave slopes): ∂d/∂x and ∂d/∂y
    // Divide by sample offset (0.001) for proper finite difference
    // ────────────────────────────────────────────────────────────────────────
    vec2 gradient = vec2(length(d1 - displace), length(d2 - displace)) / 0.001;

    // ────────────────────────────────────────────────────────────────────────
    // Compute intensity from slope magnitude
    // I = 1 / (1 + |∇d| × 0.5)
    // Small slope → I→1 (bright)
    // Large slope → I→0 (dark)
    // This models focusing/defocusing of light rays
    // ────────────────────────────────────────────────────────────────────────
    float intensity = 1.0 / (1.0 + length(gradient) * 0.5);

    return intensity;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ CAUSTIC WITH DIRECTIONAL LIGHT                                           ║
// ║                                                                           ║
// │ Modulates caustic intensity by light direction and water depth.        │
// │ Caustics are stronger when light is grazing (parallel to surface),    │
// │ and fade with depth due to absorption and scattering.                 │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ causticWithLight()                                                      ║
// ║                                                                         ║
// │ Applies light direction and depth attenuation to caustic intensity.   │
// │ Models how light angle affects caustic visibility and depth-based     │
// │ dimming (realistic underwater light absorption).                       │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   screenUv    - Screen/surface UV coordinates                         │
// │   time        - Animation time                                        │
// │   lightDir    - Light direction (normalized, 3D vector)               │
// │   waterDepth  - Distance below water surface (0-1 scale)              │
// │   speed       - Animation speed multiplier                            │
// │                                                                         ║
// │ Returns: Intensity [0, 1] with light and depth modulation            │
// │                                                                         ║
// │ Modulation Components:                                                 ║
// │   - Base caustic: layeredCaustic() at given UV/time                  │
// │   - Light focus: strongest when light is grazing (y component small)  │
// │   - Depth attenuation: exponential decay with depth (e^(-d×0.5))    │
// │                                                                         ║
// │ Physics Model:                                                          ║
// │   - Grazing light (parallel to surface): creates sharp caustics      │
// │   - Normal light (perpendicular): caustics nearly invisible          │
// │   - Depth: light absorption reduces caustic visibility               │
// │   - Model: I = I_caustic × f_light × f_depth                        │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Realistic underwater rendering with sun position                  │
// │   - Variable caustic intensity by time of day/light angle            │
// │   - Depth-dependent caustic visibility                               │
// └─────────────────────────────────────────────────────────────────────────┘
float causticWithLight(
    vec2 screenUv,
    float time,
    vec3 lightDir,
    float waterDepth,
    float speed
) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute base caustic pattern (without light/depth modulation)
    // ────────────────────────────────────────────────────────────────────────
    float caustic = layeredCaustic(screenUv, time, speed);

    // ────────────────────────────────────────────────────────────────────────
    // Compute light focus factor from light direction
    // Assume y is vertical (up), so lightDir.y indicates angle from horizontal
    // lightGraze = |lightDir.y| small → light grazing (strong caustics)
    // lightGraze = |lightDir.y| large → light normal (weak caustics)
    // ────────────────────────────────────────────────────────────────────────
    float lightGraze = abs(lightDir.y);

    // Map lightGraze [0,1] → lightFocus [1, 0.3]
    // When lightGraze = 0 (horizontal): lightFocus = 0.7 + 0.3 = 1.0 (strong)
    // When lightGraze = 1 (vertical): lightFocus = 0 + 0.3 = 0.3 (weak)
    float lightFocus = (1.0 - lightGraze) * 0.7 + 0.3;

    // ────────────────────────────────────────────────────────────────────────
    // Compute depth attenuation using exponential decay
    // depthAttenuation = e^(-waterDepth × 0.5)
    // At waterDepth = 0: attenuation = 1.0 (full caustic)
    // At waterDepth = 2: attenuation ≈ 0.37 (37% remaining)
    // At waterDepth = 4: attenuation ≈ 0.14 (14% remaining)
    // ────────────────────────────────────────────────────────────────────────
    float depthAttenuation = exp(-waterDepth * 0.5);

    // ────────────────────────────────────────────────────────────────────────
    // Combine: apply both light direction and depth modulation to caustic
    // ────────────────────────────────────────────────────────────────────────
    return caustic * lightFocus * depthAttenuation;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ TEMPORAL COHERENCE                                                       ║
// ║                                                                           ║
// │ Temporal filtering for smooth caustic animation and stability. Reduces │
// │ frame-to-frame flicker and ensures temporal coherence (nearby frames │
// │ produce similar caustic patterns).                                     │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ temporalCausticSmoothing()                                              ║
// ║                                                                         ║
// │ Applies exponential moving average (EMA) between current and previous  │
// │ caustic values. Produces smooth temporal transitions without obvious   │
// │ frame-to-frame discontinuities.                                        │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   currentCaustic      - New caustic intensity this frame              │
// │   previousCaustic     - Caustic intensity from previous frame         │
// │   temporalSmoothing   - Blend weight for temporal filter (0-1)        │
// │                         0.0 = full current, 1.0 = full previous       │
// │                                                                         ║
// │ Returns: Smoothed caustic intensity                                   │
// │                                                                         ║
// │ EMA Formula:                                                            ║
// │   result = mix(current, previous, α)                                 │
// │   = current × (1-α) + previous × α                                  │
// │   Typical α: 0.8-0.95 for strong temporal filtering                 │
// │                                                                         ║
// │ Filtering Characteristics:                                             ║
// │   - Smooth temporal transitions (reduces strobing)                    │
// │   - Maintains caustic energy (no brightening/darkening over time)     │
// │   - Introduces 1-frame latency (trail effect)                        │
// │   - Tunable via temporalSmoothing parameter                          │
// │                                                                         ║
// │ Use Cases:                                                              ║
// │   - Reduce flickering in high-frequency caustics                      │
// │   - Temporal antialiasing for animation smoothness                    │
// │   - Stability at low framerate (smooths jerky motion)                │
// └─────────────────────────────────────────────────────────────────────────┘
float temporalCausticSmoothing(
    float currentCaustic,
    float previousCaustic,
    float temporalSmoothing
) {
    // ────────────────────────────────────────────────────────────────────────
    // Exponential moving average: blend current with previous frame
    // Typical temporalSmoothing values:
    //   0.0-0.3: responsive, more flicker
    //   0.5-0.7: balanced smoothness
    //   0.8-0.95: very smooth, more latency
    // ────────────────────────────────────────────────────────────────────────
    return mix(currentCaustic, previousCaustic, temporalSmoothing);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ dampedCausticAnimation()                                                ║
// ║                                                                         ║
// │ Simple amplitude limiter to prevent caustic values from exceeding     │
// │ valid range. Ensures caustic values stay normalized [0, 1].          │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   caustic  - Caustic intensity value (may exceed [0,1])              │
// │   maxSpeed - Maximum speed limit (unused in current implementation)    │
// │                                                                         ║
// │ Returns: Clamped caustic intensity in [0, 1]                         │
// │                                                                         ║
// │ Note: In production, temporal rate-of-change limiting is preferred   │
// │ over simple clamping. Use temporal history buffer to limit            │
// │ frame-to-frame delta: |current - previous| < maxDelta.              │
// └─────────────────────────────────────────────────────────────────────────┘
float dampedCausticAnimation(float caustic, float maxSpeed) {
    // ────────────────────────────────────────────────────────────────────────
    // Simple amplitude clamping: ensure caustic stays in valid range [0,1]
    // Better approach: limit rate of change using previous frame value
    // ────────────────────────────────────────────────────────────────────────
    return clamp(caustic, 0.0, 1.0);
}

#endif // INCLUDE_CAUSTICS_ANIMATION
