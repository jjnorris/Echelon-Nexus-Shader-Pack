// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                                                                           ║
// ║            MULTI-LAYER MATERIAL COMPOSITION (PHASE 16)                   ║
// ║                                                                           ║
// ║  Stacks dielectric + metallic + specular layers for complex materials.   ║
// ║  Enables realistic materials like paint-over-metal, clear coats, and     ║
// ║  translucent/transparent layers with proper composition and blending.    ║
// ║                                                                           ║
// ║  Approach: Represents materials as ordered stacks where each layer has   ║
// ║  independent properties (albedo, roughness, metallic, thickness, IOR).   ║
// ║  Composition accounts for optical effects like transparency/absorption.  ║
// ║                                                                           ║
// ║  Applications:                                                            ║
// ║    - Car paint (metallic paint + clear coat over metallic base)          ║
// ║    - Wood finish (varnish clear coat over wood texture)                  ║
// ║    - Fabric with specular finish (cloth base + shiny coating)            ║
// ║    - Leather (base texture + subtle metallic flake layer)                ║
// ║    - Worn materials (base + weathering/oxidation layer)                  ║
// ║                                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

#ifndef INCLUDE_LAYER_MATERIALS
#define INCLUDE_LAYER_MATERIALS

#include "interference_materials.glsl"

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LAYER STRUCTURE DEFINITION                                               ║
// ║                                                                           ║
// │ Defines properties for a single layer in a stacked material system.     │
// │ Each layer can be dielectric (paint, plastic) or metallic (flakes).     │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ MaterialLayer (structure)                                               ║
// ║                                                                         ║
// │ Properties for a single layer in material composition                  │
// │   albedo:       Layer color RGB (0-1)                                 │
// │   roughness:    Surface roughness (0=mirror, 1=diffuse)               │
// │   metallic:     Metallicity (0=dielectric, 1=conductor)               │
// │   thickness:    Relative thickness (0-1, affects transparency)        │
// │   ior:          Index of refraction (1.0-2.5, typical 1.4-1.5)        │
// │   transmission: Light transmission (0=opaque, 1=fully transparent)    │
// │                                                                         ║
// │ Usage Examples:                                                         │
// │   Clear coat: high transmission (0.95), low roughness (0.05)          │
// │   Paint: medium transmission (0.8), medium roughness (0.4)            │
// │   Metal flakes: metallic 1.0, high transmission (0.9)                 │
// │   Weathering: low metallic, high roughness                            │
// └─────────────────────────────────────────────────────────────────────────┘
struct MaterialLayer {
    vec3 albedo;        // Layer color RGB
    float roughness;    // Surface roughness (0=mirror, 1=diffuse)
    float metallic;     // Metallicity (0=dielectric, 1=conductor)
    float thickness;    // Relative thickness (affects transparency)
    float ior;          // Index of refraction (dielectrics)
    float transmission; // Light transmission (0=opaque, 1=transparent)
};

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LAYER COMPOSITION                                                        ║
// ║                                                                           ║
// │ Combines multiple MaterialLayer objects into single BRDF parameters.    │
// │ Accounts for optical blending, transparency, and physical layering.     │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ ComposedMaterial (structure)                                            ║
// ║                                                                         ║
// │ Result of layer composition: final BRDF parameters for shading         │
// │   albedo:            Final blended color (0-1)                         │
// │   roughness:         Blended surface roughness (0-1)                   │
// │   metallic:          Blended metallicity (0-1)                         │
// │   opacity:           Overall opacity (0=transparent, 1=opaque)         │
// │   subsurfaceColor:   Color for translucent layer effects               │
// │                                                                         ║
// │ Composition Pipeline:                                                   ║
// │   1. Compute layer opacities from transmission values                  │
// │   2. Blend colors with alpha blending                                  │
// │   3. Blend roughness (coat is typically smoother)                      │
// │   4. Reduce metallic when coat covers (coat masks metallic)            │
// │   5. Compute subsurface visibility through coat                        │
// └─────────────────────────────────────────────────────────────────────────┘
struct ComposedMaterial {
    vec3 albedo;            // Final blended color
    float roughness;        // Blended roughness
    float metallic;         // Blended metallicity
    float opacity;          // Overall material opacity
    vec3 subsurfaceColor;   // For translucent effects
};

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ composeLayers()                                                         ║
// ║                                                                         ║
// │ Composes two material layers (base + coat) into single BRDF params.     │
// │ Uses alpha blending for colors and physical reasoning for roughness    │
// │ and metallic properties.                                                │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   base         - Base material layer (typically metallic/rough)        │
// │   coat         - Coat material layer (typically dielectric/smooth)     │
// │   coatStrength - Blend weight for coat (0=no coat, 1=full coat)       │
// │   viewAngle    - Viewing angle (for future interference effects)       │
// │                                                                         ║
// │ Returns: ComposedMaterial with properly blended properties             │
// │                                                                         ║
// │ Composition Rules:                                                      ║
// │   - Color: Alpha blend using coat.transmission * coatStrength          │
// │   - Roughness: Coat typically smoother (blends toward coat.roughness)  │
// │   - Metallic: Coat is dielectric, masks metallic base                  │
// │   - Opacity: Combined via Porter-Duff over compositing                 │
// │   - Subsurface: Visible through transparent coat                       │
// │                                                                         ║
// │ Examples:                                                               ║
// │   Clear coat over metal:                                                │
// │     coat: {transmission 0.95, roughness 0.05}                         │
// │     Result: Smooth, shiny, slightly reflects coat color                │
// │   Paint over base:                                                      │
// │     coat: {transmission 0.8, roughness 0.3}                           │
// │     Result: Semi-rough, full base coverage                             │
// └─────────────────────────────────────────────────────────────────────────┘
ComposedMaterial composeLayers(
    MaterialLayer base,
    MaterialLayer coat,
    float coatStrength,
    float viewAngle
) {
    ComposedMaterial result;

    // ────────────────────────────────────────────────────────────────────────
    // Compute layer opacities
    // coatOpacity = how much the coat contributes (0=coat invisible, 1=full)
    // baseOpacity = how much the base shows through (complementary)
    // ────────────────────────────────────────────────────────────────────────
    float coatOpacity = coat.transmission * coatStrength;
    float baseOpacity = 1.0 - coatOpacity;

    // ────────────────────────────────────────────────────────────────────────
    // Alpha blend colors: coat over base (standard over compositing)
    // result.C = coat.C × α_coat + base.C × (1 - α_coat)
    // ────────────────────────────────────────────────────────────────────────
    result.albedo = mix(base.albedo, coat.albedo, coatOpacity);

    // ────────────────────────────────────────────────────────────────────────
    // Roughness blending: coat is typically smoother
    // Top layer roughness becomes dominant (coat masks base roughness)
    // ────────────────────────────────────────────────────────────────────────
    result.roughness = mix(base.roughness, coat.roughness, coatOpacity);

    // ────────────────────────────────────────────────────────────────────────
    // Metallic: coat (dielectric) masks metallic base
    // Metallic base only visible if coat is transparent (baseOpacity > 0)
    // ────────────────────────────────────────────────────────────────────────
    result.metallic = base.metallic * baseOpacity;

    // ────────────────────────────────────────────────────────────────────────
    // Overall opacity: Porter-Duff over formula
    // opacity = coat + base × (1 - coat)
    // ────────────────────────────────────────────────────────────────────────
    result.opacity = base.transmission + coat.transmission * (1.0 - base.transmission);

    // ────────────────────────────────────────────────────────────────────────
    // Subsurface: visible through transparent coat only
    // Reduced by coat opacity (thicker coat = less subsurface visibility)
    // ────────────────────────────────────────────────────────────────────────
    result.subsurfaceColor = base.albedo * (1.0 - coatOpacity);

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ SPECIALIZED MATERIAL PRESETS                                             ║
// ║                                                                           ║
// │ Pre-configured material compositions for common real-world materials.   │
// │ Each preset handles typical layering and properties for that material   │
// │ type, with parameters exposed for customization.                        │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ paintedMetal()                                                          ║
// ║                                                                         ║
// │ Creates realistic car-paint or painted-metal material with three       │
// │ layers: metallic base → paint layer → clear coat.                      │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   paintColor         - Paint color (RGB 0-1)                          │
// │   paintRoughness     - Paint surface roughness (0-1)                  │
// │   metalColor         - Base metal color (typically light gray)         │
// │   metalRoughness     - Metal surface roughness (0-1)                  │
// │   clearCoatStrength  - Clear coat blending strength (0-1)             │
// │                                                                         ║
// │ Returns: ComposedMaterial with all three layers properly composed     │
// │                                                                         ║
// │ Composition Layers:                                                     ║
// │   Layer 1: Metal base (metallic=1.0, rough)                          │
// │   Layer 2: Paint (metallic=0.0, semi-rough)                          │
// │   Layer 3: Clear coat (metallic=0.0, very smooth=0.05)               │
// │                                                                         ║
// │ Typical Application (car paint):                                        ║
// │   paintColor: [0.8, 0.1, 0.1] (bright red)                           │
// │   paintRoughness: 0.3 (glossy paint)                                  │
// │   metalColor: [0.7, 0.7, 0.7] (light gray metal)                     │
// │   metalRoughness: 0.4 (slightly rough metal)                          │
// │   clearCoatStrength: 0.8 (strong clear coat)                          │
// └─────────────────────────────────────────────────────────────────────────┘
ComposedMaterial paintedMetal(
    vec3 paintColor,
    float paintRoughness,
    vec3 metalColor,
    float metalRoughness,
    float clearCoatStrength
) {
    // ────────────────────────────────────────────────────────────────────────
    // Layer 1: Metallic base (aluminum, steel flake)
    // Metallic: 1.0 (fully conducting)
    // Transmission: 0.1 (opaque, metal base)
    // Thickness: 0.8 (substantial metal layer)
    // ────────────────────────────────────────────────────────────────────────
    MaterialLayer metal = MaterialLayer(
        metalColor, metalRoughness, 1.0, 0.8, 1.5, 0.1
    );

    // ────────────────────────────────────────────────────────────────────────
    // Layer 2: Paint (color layer, opaque)
    // Metallic: 0.0 (dielectric paint)
    // Transmission: 0.8 (mostly opaque, thin transparency)
    // Thickness: 0.9 (thick enough to hide metal)
    // ────────────────────────────────────────────────────────────────────────
    MaterialLayer paint = MaterialLayer(
        paintColor, paintRoughness, 0.0, 0.9, 1.5, 0.8
    );

    // ────────────────────────────────────────────────────────────────────────
    // Layer 3: Clear protective coat
    // Roughness: 0.05 (very smooth, typical clear coat)
    // Transmission: 0.95 (nearly transparent, just adds gloss)
    // Thickness: 1.0 (thin but affects surface properties)
    // ────────────────────────────────────────────────────────────────────────
    MaterialLayer clearCoat = MaterialLayer(
        vec3(1.0), 0.05, 0.0, 1.0, 1.4, 0.95
    );

    // ────────────────────────────────────────────────────────────────────────
    // Compose paint over metal (primary composition)
    // ────────────────────────────────────────────────────────────────────────
    ComposedMaterial painted = composeLayers(metal, paint, 1.0, 0.5);

    // ────────────────────────────────────────────────────────────────────────
    // Apply clear coat over painted result
    // Create temporary layer from composed result for second composition
    // ────────────────────────────────────────────────────────────────────────
    MaterialLayer coatLayer = MaterialLayer(
        painted.albedo, painted.roughness, painted.metallic, 1.0, 1.4, 0.9
    );

    return composeLayers(coatLayer, clearCoat, clearCoatStrength, 0.5);
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ fabricMaterial()                                                        ║
// ║                                                                         ║
// │ Creates fabric/cloth material: rough surface with light transmission. │
// │ Suitable for textiles, canvas, tapestries with potential subsurface  │
// │ light scattering.                                                      ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   fabricColor           - Base cloth color (RGB 0-1)                  │
// │   roughness             - Surface roughness (0-1, clamped to 0.5-1.0)│
// │   subsurfaceIntensity   - Light transmission amount (0-1)             │
// │                                                                         ║
// │ Returns: ComposedMaterial with fabric properties                      │
// │                                                                         ║
// │ Typical Values:                                                         ║
// │   fabricColor: [0.5, 0.4, 0.35] (tan cloth)                          │
// │   roughness: 0.8 (fabrics are inherently rough)                       │
// │   subsurfaceIntensity: 0.3 (some light passes through)                │
// └─────────────────────────────────────────────────────────────────────────┘
ComposedMaterial fabricMaterial(
    vec3 fabricColor,
    float roughness,
    float subsurfaceIntensity
) {
    ComposedMaterial result;

    // ────────────────────────────────────────────────────────────────────────
    // Fabric is always dielectric (non-metallic)
    // ────────────────────────────────────────────────────────────────────────
    result.albedo = fabricColor;

    // ────────────────────────────────────────────────────────────────────────
    // Fabrics are inherently rough (min 0.5, max 1.0)
    // Smooth fabrics still have visible texture due to fiber structure
    // ────────────────────────────────────────────────────────────────────────
    result.roughness = clamp(roughness, 0.5, 1.0);

    // ────────────────────────────────────────────────────────────────────────
    // Metallic: fabrics never have metallic luster
    // ────────────────────────────────────────────────────────────────────────
    result.metallic = 0.0;

    // ────────────────────────────────────────────────────────────────────────
    // Opacity inversely related to subsurface transmission
    // If subsurfaceIntensity = 0.3, opacity = 0.7 (mostly opaque)
    // ────────────────────────────────────────────────────────────────────────
    result.opacity = 1.0 - subsurfaceIntensity;

    // ────────────────────────────────────────────────────────────────────────
    // Subsurface color: fabric color modulated by transmission amount
    // Light passing through is colored by the fabric pigment
    // ────────────────────────────────────────────────────────────────────────
    result.subsurfaceColor = fabricColor * subsurfaceIntensity;

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ plasticMaterial()                                                       ║
// ║                                                                         ║
// │ Creates plastic material: dielectric, smooth to glossy finish.         │
// │ Models typical polymers (ABS, polycarbonate) with adjustable gloss.   │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   plasticColor - Plastic color (RGB 0-1)                             │
// │   gloss        - Surface gloss level (0-1, higher=shinier)           │
// │                                                                         ║
// │ Returns: ComposedMaterial with plastic properties                     │
// │                                                                         ║
// │ Typical Values:                                                         ║
// │   plasticColor: [0.2, 0.2, 0.25] (dark plastic)                      │
// │   gloss: 0.7 (typical injection-molded plastic)                       │
// │   Result: roughness = 0.3, metallic = 0                              │
// └─────────────────────────────────────────────────────────────────────────┘
ComposedMaterial plasticMaterial(
    vec3 plasticColor,
    float gloss
) {
    ComposedMaterial result;

    result.albedo = plasticColor;

    // ────────────────────────────────────────────────────────────────────────
    // Roughness inversely mapped from gloss
    // gloss = 1.0 (mirror) → roughness = 0.0
    // gloss = 0.0 (matte) → roughness = 1.0
    // ────────────────────────────────────────────────────────────────────────
    result.roughness = 1.0 - gloss;

    // ────────────────────────────────────────────────────────────────────────
    // Plastic is always dielectric (non-metallic)
    // ────────────────────────────────────────────────────────────────────────
    result.metallic = 0.0;

    // ────────────────────────────────────────────────────────────────────────
    // Plastic is opaque (no subsurface light transmission typical)
    // ────────────────────────────────────────────────────────────────────────
    result.opacity = 1.0;
    result.subsurfaceColor = vec3(0.0);

    return result;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ rubberMaterial()                                                        ║
// ║                                                                         ║
// │ Creates rubber/elastomer material: very rough, light-absorbing.       │
// │ Models natural rubber, synthetic rubber, silicone with weathering     │
// │ effects (UV exposure, oxidation).                                      ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   rubberColor - Base rubber color (RGB 0-1)                          │
// │   weathering  - Weathering amount (0=new, 1=heavily weathered)       │
// │                                                                         ║
// │ Returns: ComposedMaterial with rubber properties                      │
// │                                                                         ║
// │ Typical Values:                                                         ║
// │   rubberColor: [0.1, 0.1, 0.1] (black rubber)                        │
// │   weathering: 0.3 (slight oxidation/fading)                          │
// │   Result: roughness = 0.93, metallic = 0                             │
// │                                                                         ║
// │ Weathering Effects:                                                     ║
// │   - weathering = 0: albedo = 80% original, roughness = 90%           │
// │   - weathering = 1: albedo = 100% original, roughness = 100%         │
// └─────────────────────────────────────────────────────────────────────────┘
ComposedMaterial rubberMaterial(
    vec3 rubberColor,
    float weathering
) {
    ComposedMaterial result;

    // ────────────────────────────────────────────────────────────────────────
    // Weathering lightens rubber (UV exposure fades black rubber)
    // New rubber: 80% of original color
    // Weathered: full original color (fading from oxidation)
    // ────────────────────────────────────────────────────────────────────────
    result.albedo = rubberColor * (0.8 + 0.2 * weathering);

    // ────────────────────────────────────────────────────────────────────────
    // Rubber is extremely rough (90-100% roughness)
    // Weathering slightly increases surface roughness (oxidation)
    // ────────────────────────────────────────────────────────────────────────
    result.roughness = 0.9 + 0.1 * weathering;

    // ────────────────────────────────────────────────────────────────────────
    // Rubber is never metallic (dielectric elastomer)
    // ────────────────────────────────────────────────────────────────────────
    result.metallic = 0.0;

    // ────────────────────────────────────────────────────────────────────────
    // Rubber is opaque (no light transmission)
    // ────────────────────────────────────────────────────────────────────────
    result.opacity = 1.0;
    result.subsurfaceColor = vec3(0.0);

    return result;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LAYER-AWARE FRESNEL                                                      ║
// ║                                                                           ║
// │ Computes Fresnel response accounting for material layer composition.   │
// │ Blends metallic and dielectric F0 values based on composition,         │
// │ then applies Schlick's approximation with opacity modulation.          │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ fresnelComposed()                                                       ║
// ║                                                                         ║
// │ Computes Fresnel reflectance for composed multi-layer material.        │
// │ Properly blends metallic (conductor) and dielectric F0 values          │
// │ according to material composition, then applies Schlick with opacity.  │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   material               - ComposedMaterial from layer composition     │
// │   HdotV                  - Half-vector dot view (0=grazing, 1=normal) │
// │   baseF0_metallic        - F0 for metallic (typical 0.0 for metals)   │
// │   baseF0_dielectric      - F0 for dielectric (typical 0.04)           │
// │                                                                         ║
// │ Returns: Fresnel reflectance [0, 1] accounting for composition       │
// │                                                                         ║
// │ Physics:                                                                ║
// │   1. Metallic F0 = albedo color (metal's natural reflectance)         │
// │   2. Dielectric F0 = constant (0.04 for most dielectrics)             │
// │   3. Blended F0 = mix using material.metallic weight                  │
// │   4. Schlick: F = F₀ + (1-F₀)×(1-cos(θ))⁵                           │
// │   5. Final: modulate by opacity (transparent → less reflection)       │
// │                                                                         ║
// │ Example:                                                                │
// │   - Pure metallic (metallic=1): F0=albedo, strong reflection          │
// │   - Pure dielectric (metallic=0): F0=0.04, weak reflection            │
// │   - 50/50 blend: F0 = 0.5×albedo + 0.5×0.04                         │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 fresnelComposed(
    ComposedMaterial material,
    float HdotV,
    float baseF0_metallic,
    float baseF0_dielectric
) {
    // ────────────────────────────────────────────────────────────────────────
    // Metallic F0: use material albedo color (natural metal reflectance)
    // For example: gold F0 ≈ [1.0, 0.84, 0.04] (yellowish)
    // ────────────────────────────────────────────────────────────────────────
    vec3 F0_metal = material.albedo;

    // ────────────────────────────────────────────────────────────────────────
    // Dielectric F0: typical value for organic dielectrics (0.04)
    // Accounts for IOR of ~1.5 (glass, paint, plastic)
    // F0 = ((n-1)/(n+1))² where n=1.5 → F0≈0.04
    // ────────────────────────────────────────────────────────────────────────
    vec3 F0_dielectric = vec3(baseF0_dielectric);

    // ────────────────────────────────────────────────────────────────────────
    // Blend F0 based on material metallic property
    // Pure dielectric (metallic=0): F0 = F0_dielectric
    // Pure metallic (metallic=1): F0 = F0_metal
    // ────────────────────────────────────────────────────────────────────────
    vec3 F0 = mix(F0_dielectric, F0_metal, material.metallic);

    // ────────────────────────────────────────────────────────────────────────
    // Apply Schlick's Fresnel approximation: F = F₀ + (1-F₀)×(1-cos(θ))⁵
    // Clamped HdotV to [0, 1] to prevent numerical issues
    // ────────────────────────────────────────────────────────────────────────
    vec3 fresnel = F0 + (1.0 - F0) * pow(clamp(1.0 - HdotV, 0.0, 1.0), 5.0);

    // ────────────────────────────────────────────────────────────────────────
    // Modulate Fresnel by material opacity
    // Transparent materials (opacity < 1) have reduced reflectance
    // opacity=1.0: full Fresnel response
    // opacity=0.5: half strength Fresnel
    // ────────────────────────────────────────────────────────────────────────
    fresnel *= material.opacity;

    return fresnel;
}

// ╔───────────────────────────────────────────────────────────────────────────╗
// ║ LAYER THICKNESS EFFECTS                                                  ║
// ║                                                                           ║
// │ Models absorption of light passing through layers using Beer-Lambert   │
// │ law. Thicker layers absorb more light, creating color/darkening.      │
// └───────────────────────────────────────────────────────────────────────────┘

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ computeAbsorption()                                                     ║
// ║                                                                         ║
// │ Computes light transmission through absorbing layer using Beer-       │
// │ Lambert law: T = e^(-μ×d) where μ is absorption coefficient, d is     │
// │ thickness.                                                              ║
// │                                                                         ║
// │ Parameters:                                                            ║
// │   thickness              - Layer thickness (0-1 scale)                 │
// │   absorptionCoefficient  - Per-channel absorption (RGB)                │
// │                           Typical: [0.1, 0.1, 0.1] to [1.0, 1.0, 1.0]│
// │                                                                         ║
// │ Returns: Average transmission across RGB (0-1)                         │
// │                                                                         ║
// │ Physics: Beer-Lambert transmission T = e^(-α×d)                       │
// │ High absorption (α=1.0) at thickness=1.0 → T≈0.37 (63% loss)         │
// │ Low absorption (α=0.1) at thickness=1.0 → T≈0.90 (10% loss)         │
// │                                                                         ║
// │ Application: Color becomes darker/shifted as it passes through layer   │
// └─────────────────────────────────────────────────────────────────────────┘
float computeAbsorption(float thickness, vec3 absorptionCoefficient) {
    // ────────────────────────────────────────────────────────────────────────
    // Apply Beer-Lambert law: T = e^(-μ × d)
    // Separate computation for each channel (different absorption per color)
    // ────────────────────────────────────────────────────────────────────────
    vec3 transmission = exp(-absorptionCoefficient * thickness);

    // ────────────────────────────────────────────────────────────────────────
    // Average transmission across RGB channels
    // Returns single scalar [0, 1] representing overall light transmission
    // ────────────────────────────────────────────────────────────────────────
    return (transmission.r + transmission.g + transmission.b) / 3.0;
}

// ╔─────────────────────────────────────────────────────────────────────────╗
// ║ applyThicknessAbsorption()                                              ║
// ║                                                                         ║
// │ Applies thickness-based color darkening/shifting. Simpler approximation│
// │ than full Beer-Lambert: assumes uniform absorption across RGB.         │
// │                                                                         ║
// │ Parameters:                                                            ║
// │   color        - Base color to darken (RGB 0-1)                       │
// │   thickness    - Current thickness (0-1)                              │
// │   maxThickness - Reference thickness for 100% absorption (0-1)        │
// │                                                                         ║
// │ Returns: Darkened color accounting for absorption                      │
// │                                                                         ║
// │ Behavior:                                                               ║
// │   thickness=0 (no layer):      color × 1.0 (no darkening)            │
// │   thickness=maxThickness/2:    color × 0.5 (50% darker)              │
// │   thickness≥maxThickness:      color × 0.0 (completely absorbed)      │
// │                                                                         ║
// │ Use Case: Quick approximation for semi-transparent layers (varnish)   │
// └─────────────────────────────────────────────────────────────────────────┘
vec3 applyThicknessAbsorption(
    vec3 color,
    float thickness,
    float maxThickness
) {
    // ────────────────────────────────────────────────────────────────────────
    // Clamp normalized thickness to [0, 1]
    // ────────────────────────────────────────────────────────────────────────
    float normalizedThickness = clamp(thickness / maxThickness, 0.0, 1.0);

    // ────────────────────────────────────────────────────────────────────────
    // Linear absorption: higher thickness = lower transmission factor
    // absorption = 1.0 - (thickness / maxThickness)
    // Creates linear darkening from 100% (no thickness) to 0% (full)
    // ────────────────────────────────────────────────────────────────────────
    float absorption = 1.0 - normalizedThickness;

    // ────────────────────────────────────────────────────────────────────────
    // Apply absorption factor to color (multiplicative darkening)
    // ────────────────────────────────────────────────────────────────────────
    return color * absorption;
}

#endif // INCLUDE_LAYER_MATERIALS
