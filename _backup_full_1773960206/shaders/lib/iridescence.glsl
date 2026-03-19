// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║                     IRIDESCENCE EFFECTS (PHASE 16)                       ║
// ║                                                                           ║
// ║  Viewing-angle dependent color variation for iridescent materials.       ║
// ║  Produces smooth color shifts for oil slicks, butterfly wings, soap      ║
// ║  bubbles, mother-of-pearl using HSV-space color transitions and         ║
// ║  optional thin-film interference patterns.                               ║
// ║                                                                           ║
// ║  Theory: Iridescence from spectral interference when light bounces      ║
// ║  through thin, layered structures. Different viewing angles produce      ║
// ║  different path lengths → different phase shifts → different colors.    ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_IRIDESCENCE
#define INCLUDE_IRIDESCENCE

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ IRIDESCENT COLOR MAPPING                                                 ║
// ║                                                                           ║
// │ Maps viewing angle to iridescent colors through HSV color space.        │
// │ Produces characteristic color transitions seen in soap bubbles and       │
// │ oil films (blue → cyan → green → yellow → red).                         │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ iridsentColor()                                                          ║
// ║                                                                         ║
// │ Generates smooth iridescent color based on viewing angle using HSV     │
// │ space. Hue rotates continuously, saturation and brightness modulate    │
// │ to create perceptually convincing color shifts.                        │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle        - Viewing angle from surface normal (0 to π/2)         │
// │   saturation   - Saturation modulation strength (0-1)                  │
// │   brightness   - Brightness modulation strength (0-1)                  │
// │                                                                         ║
// │ Returns: RGB color (normalized 0-1)                                   │
// │                                                                         ║
// │ Color Progression:                                                      ║
// │   - 0° (normal):  Blue-ish with peaks                                 │
// │   - 45° (glance): Green-yellow with modulation                        │
// │   - 90° (edge):   Red-ish with dimming                                │
// │                                                                         ║
// │ Modulation: Brightness oscillates (~4× frequency) to simulate          │
// │ multiple thin-film orders creating periodic dimming                    │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 iridsentColor(float angle, float saturation, float brightness) {
    // ────────────────────────────────────────────────────────────────────────
    // Normalize angle to [0, 1] (0 = normal viewing, 1 = grazing/edge)
    // ────────────────────────────────────────────────────────────────────────
    float t = angle / 1.5707963; // Divide by π/2

    // ────────────────────────────────────────────────────────────────────────
    // Hue rotation: 240° (blue) → 0° (red) → back to 240° (wraps)
    // Linear interpolation from blue through green/yellow to red
    // ────────────────────────────────────────────────────────────────────────
    float hue = 240.0 - t * 240.0;  // 240° to 0°
    if (hue < 0.0) hue += 360.0;    // Wrap around for magenta

    // ────────────────────────────────────────────────────────────────────────
    // Saturation modulation: sin(angle) peaks at 45-60° (glancing angle)
    // At normal (0°) and extreme grazing (90°) saturation drops
    // ────────────────────────────────────────────────────────────────────────
    float satMod = sin(angle) * saturation;

    // ────────────────────────────────────────────────────────────────────────
    // Brightness modulation: cosine at 4× frequency simulates interference
    // Creates periodic bright/dim bands typical of thin-film colors
    // ────────────────────────────────────────────────────────────────────────
    float brightMod = 0.5 + 0.5 * cos(angle * 4.0) * brightness;

    // ────────────────────────────────────────────────────────────────────────
    // Convert HSV to RGB (hue in [0,1], saturation and brightness as computed)
    // ────────────────────────────────────────────────────────────────────────
    return hsv2rgb(vec3(hue / 360.0, satMod, brightMod));
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ hsv2rgb()                                                               ║
// ║                                                                         ║
// │ Converts HSV (Hue, Saturation, Value) color space to RGB.             │
// │ Standard HSV→RGB conversion using sector-based interpolation.          │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   c - HSV color (x=hue [0,1], y=saturation [0,1], z=value [0,1])    │
// │                                                                         ║
// │ Returns: RGB color (normalized 0-1)                                   │
// │                                                                         ║
// │ Implementation: 6-sector hue interpolation for smooth color gradients  │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rgb2hsv()                                                               ║
// ║                                                                         ║
// │ Converts RGB color space to HSV (Hue, Saturation, Value).             │
// │ Useful for analyzing texture colors and applying HSV-based effects.    │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   c - RGB color (normalized 0-1 for each channel)                     │
// │                                                                         ║
// │ Returns: HSV color (hue [0,1], saturation [0,1], value [0,1])        │
// │                                                                         ║
// │ Computation: Based on max/min RGB values and hue sector detection      │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LAYERED IRIDESCENCE                                                      ║
// ║                                                                           ║
// │ Multi-layer thin-film iridescence with phase interference. Simulates    │
// │ multiple scattering orders (reflections within the film) for realistic  │
// │ soap bubbles and oil films that show multiple color orders.             │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ IridescenceResult (structure)                                           ║
// ║                                                                         ║
// │ Result of multi-order iridescence computation                          │
// │   color:     Final iridescent RGB (0-1)                                │
// │   intensity: Combined intensity from all orders (0-1)                  │
// │   order:     Number of orders computed (for debugging/feedback)        │
// └─────────────────────────────────────────────────────────────────────────┘
struct IridescenceResult {
    vec3 color;      // Final iridescent color
    float intensity; // Intensity modifier
    float order;     // Interference order (useful for feedback)
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeLayeredIridescence()                                             ║
// ║                                                                         ║
// │ Computes iridescence with multiple thin-film interference orders.      │
// │ Each order represents a different bounce depth within the film,         │
// │ with higher orders dimmer but producing richer color variation.         │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   viewAngle  - Viewing angle from surface normal (radians)            │
// │   thickness  - Film thickness (0-1 scale)                             │
// │   n_film     - Refractive index of film (1.3-1.5)                     │
// │   strength   - Saturation strength for color (0-1)                    │
// │   orders     - Number of interference orders to compute (1-4)         │
// │                                                                         ║
// │ Returns: IridescenceResult with color and intensity modulation        │
// │                                                                         ║
// │ Behavior:                                                               ║
// │   - Order 1: Primary (brightest) color                                │
// │   - Order 2: Secondary color, dimmed 50%                              │
// │   - Order 3: Tertiary color, dimmed 67%                               │
// │   - Final: Average across all orders with weighting                   │
// │                                                                         ║
// │ Physics: Each order has OPD = n × 2 × thickness × cos(angle)         │
// │ Different OPD creates different phase shifts per order                │
// └─────────────────────────────────────────────────────────────────────────┘
IridescenceResult computeLayeredIridescence(
    float viewAngle,
    float thickness,
    float n_film,
    float strength,
    int orders
) {
    IridescenceResult result = IridescenceResult(vec3(0.0), 0.0, 0.0);

    // ────────────────────────────────────────────────────────────────────────
    // Compute base iridescence color from viewing angle
    // ────────────────────────────────────────────────────────────────────────
    vec3 baseColor = iridsentColor(viewAngle, strength, 0.5);

    // ────────────────────────────────────────────────────────────────────────
    // Compute intensity modulation from multiple scattering orders
    // Each order has different optical path length → different phase
    // ────────────────────────────────────────────────────────────────────────
    float totalIntensity = 0.0;
    for (int i = 1; i <= orders; i++) {
        // ────────────────────────────────────────────────────────────────────
        // OPD for order i: multiple reflections give i × path length
        // ────────────────────────────────────────────────────────────────────
        float opd = float(i) * 2.0 * thickness;

        // ────────────────────────────────────────────────────────────────────
        // Convert OPD to phase for green wavelength (550nm)
        // ────────────────────────────────────────────────────────────────────
        float phase = 2.0 * 3.14159265359 * opd / 0.55;

        // ────────────────────────────────────────────────────────────────────
        // Compute intensity via interference fringe formula
        // Higher orders are dimmed by factor 1/i (energy conservation)
        // ────────────────────────────────────────────────────────────────────
        float orderIntensity = (1.0 + cos(phase)) * 0.5;
        totalIntensity += orderIntensity / float(i);
    }
    totalIntensity /= float(orders);

    result.color = baseColor;
    result.intensity = totalIntensity;
    result.order = float(orders);

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ PEACOCK-FEATHER STYLE IRIDESCENCE                                        ║
// ║                                                                           ║
// │ Mimics sharp color transitions characteristic of peacock feathers.      │
// │ Uses discontinuous band transitions for distinctive iridescent effect.  │
// │ Different from smooth mathematical iridescence - perceptually distinct. │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ peacockIridescence()                                                    ║
// ║                                                                         ║
// │ Generates peacock-feather style color bands with sharp transitions.     │
// │ Creates discrete color zones typical of structural coloration in       │
// │ peacock feathers: deep blues → greens → yellows → reds.                │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle - Viewing angle from surface normal (0 to π/2)                │
// │                                                                         ║
// │ Returns: RGB color with distinct peacock-like color bands             │
// │                                                                         ║
// │ Color Bands (by angle):                                                 ║
// │   0-25%:   Deep blue → cyan (primarily blue)                          │
// │   25-50%:  Cyan → green (blue fades, green rises)                     │
// │   50-75%:  Green → yellow (adding red for yellow)                     │
// │   75-100%: Yellow → red (blue fades, red intensifies)                 │
// │                                                                         ║
// │ Style: Discrete bands vs. continuous gradients for bold appearance     │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 peacockIridescence(float angle) {
    // ────────────────────────────────────────────────────────────────────────
    // Normalize angle to [0, 1] parameter
    // ────────────────────────────────────────────────────────────────────────
    float t = angle / 1.5707963; // π/2

    vec3 color;
    if (t < 0.25) {
        // ────────────────────────────────────────────────────────────────────
        // Deep blue band (0-25%): from dark blue to cyan
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.0, 0.0, 0.3), vec3(0.0, 0.3, 0.8), t / 0.25);
    } else if (t < 0.5) {
        // ────────────────────────────────────────────────────────────────────
        // Cyan to green transition (25-50%): blue fades, green rises
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.0, 0.3, 0.8), vec3(0.0, 0.8, 0.4), (t - 0.25) / 0.25);
    } else if (t < 0.75) {
        // ────────────────────────────────────────────────────────────────────
        // Green to yellow transition (50-75%): add red component for yellow
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.0, 0.8, 0.4), vec3(0.8, 0.8, 0.0), (t - 0.5) / 0.25);
    } else {
        // ────────────────────────────────────────────────────────────────────
        // Yellow to red transition (75-100%): reduce green, keep red/yellow
        // ────────────────────────────────────────────────────────────────────
        color = mix(vec3(0.8, 0.8, 0.0), vec3(0.8, 0.1, 0.0), (t - 0.75) / 0.25);
    }

    return color;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SOAP-BUBBLE STYLE IRIDESCENCE                                           ║
// ║                                                                           ║
// │ Produces characteristic thin-film color progression of soap bubbles.   │
// │ Uses proper optical path difference and wavelength-dependent           │
// │ interference for physically-based color shifts.                         │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ soapBubbleIridescence()                                                 ║
// ║                                                                         ║
// │ Generates soap-bubble iridescence using true thin-film physics.        │
// │ Each RGB channel interferes independently, creating the gradual        │
// │ color progression seen in real soap bubbles (violet → red → repeat).   │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   angle     - Viewing angle from normal (0 to π/2)                    │
// │   thickness - Film thickness (0-1 scale, affects color spacing)       │
// │                                                                         ║
// │ Returns: RGB intensities [0, 1] from thin-film interference           │
// │                                                                         ║
// │ Physics:                                                                ║
// │   - Red (650nm): Largest period, colors repeat slowly with angle     │
// │   - Green (550nm): Medium period, middle cycle                        │
// │   - Blue (450nm): Smallest period, colors repeat quickly              │
// │   - Combined RGB → full visible spectrum colors with angle            │
// │                                                                         ║
// │ Color Progression (typical):                                            ║
// │   Thin film (0.05μm): Violet/blue → greens → reds                    │
// │   Medium (0.2μm): Multiple repeats of full spectrum                   │
// │   Thick (1.0μm): Complex color mixing from overlapping periods        │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 soapBubbleIridescence(float angle, float thickness) {
    // ────────────────────────────────────────────────────────────────────────
    // Compute optical path difference using cosine of refraction angle
    // OPD = 2 × n × thickness × cos(θ_refracted)
    // Note: using cos(angle) as approximation for refracted angle
    // ────────────────────────────────────────────────────────────────────────
    float opd = 2.0 * thickness * cos(angle);

    // ────────────────────────────────────────────────────────────────────────
    // RGB wavelengths in normalized units
    // Red: 650nm, Green: 550nm, Blue: 450nm
    // Shorter wavelengths have higher frequencies → phase faster with OPD
    // ────────────────────────────────────────────────────────────────────────
    vec3 wavelengths = vec3(650.0, 550.0, 450.0);

    // ────────────────────────────────────────────────────────────────────────
    // Compute phase shift for each wavelength
    // Phase = 2π × OPD / λ
    // ────────────────────────────────────────────────────────────────────────
    vec3 phases = (2.0 * 3.14159265359 * opd) / wavelengths;

    // ────────────────────────────────────────────────────────────────────────
    // Convert phases to intensities via thin-film interference formula
    // I = (1 + cos(φ)) / 2 (two-beam interference)
    // ────────────────────────────────────────────────────────────────────────
    vec3 intensities = vec3(
        0.5 + 0.5 * cos(phases.r),  // Red channel interference
        0.5 + 0.5 * cos(phases.g),  // Green channel interference
        0.5 + 0.5 * cos(phases.b)   // Blue channel interference
    );

    return intensities;
}

#endif // INCLUDE_IRIDESCENCE
