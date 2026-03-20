// ============================================================================
// BRDF LIBRARY
// Physically-Based Rendering Functions
// ============================================================================
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
// - Cook-Torrance GGX Microfacet Model
//
// Purpose: Core Cook-Torrance GGX BRDF implementation for photorealistic rendering
// Includes: Fresnel, Distribution (GGX), Geometry term, Energy conservation

#ifndef INCLUDED_BRDF
#define INCLUDED_BRDF

// ============================================================================
// FRESNEL TERM - Schlick Approximation
// ============================================================================
// Determines how much light reflects vs refracts at different angles
// F0 = base reflectance (0.04 for dielectrics, metallic F0 varies)

float fresnelSchlick(float cosTheta, float f0) {
	// Schlick approximation: F(h,l) = F0 + (1-F0) * (1 - cos(h·l))^5
	return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 fresnelSchlickVec(float cosTheta, vec3 f0) {
	return f0 + (vec3(1.0) - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Fresnel with roughness adjustment
// Reference: Complementary Shaders fresnel implementation
float fresnelRoughness(float cosTheta, float f0, float roughness) {
	return fresnelSchlick(cosTheta, mix(f0, 1.0, roughness * roughness));
}

// ============================================================================
// DISTRIBUTION FUNCTION - GGX (Trowbridge-Reitz)
// ============================================================================
// Determines microfacet distribution - how rough the surface is
// Alpha = roughness squared

float distributionGGX(vec3 normal, vec3 halfDir, float roughness) {
	float a = roughness * roughness;
	float a2 = a * a;
	float nhDot = max(dot(normal, halfDir), 0.0);
	float nhDot2 = nhDot * nhDot;

	// GGX formula: D = a^2 / (π * (nh^2 * (a^2 - 1) + 1)^2)
	float denom = (nhDot2 * (a2 - 1.0) + 1.0);
	return a2 / (3.14159265 * denom * denom);
}

// ============================================================================
// GEOMETRY FUNCTION - Smith Height-Correlated
// ============================================================================
// Accounts for self-shadowing of microfacets

float geometrySchlickGGX(float nDot, float roughness) {
	float r = (roughness + 1.0);
	float k = (r * r) / 8.0;  // Direct lighting remapping

	return nDot / (nDot * (1.0 - k) + k);
}

float geometrySmith(float nDotV, float nDotL, float roughness) {
	float ggx2 = geometrySchlickGGX(nDotV, roughness);
	float ggx1 = geometrySchlickGGX(nDotL, roughness);

	return ggx1 * ggx2;
}

// Height-correlated (improved Smith)
// Reference: Epic Games implementation
float geometrySmithHeightCorrelated(vec3 normal, vec3 viewDir, vec3 lightDir, float roughness) {
	float nDotV = max(dot(normal, viewDir), 0.0);
	float nDotL = max(dot(normal, lightDir), 0.0);

	float alpha = roughness * roughness;
	float alpha2 = alpha * alpha;

	float denomA = nDotV * sqrt(alpha2 + (1.0 - alpha2) * nDotL * nDotL);
	float denomB = nDotL * sqrt(alpha2 + (1.0 - alpha2) * nDotV * nDotV);

	return 0.5 / max(denomA + denomB, 0.001);
}

// ============================================================================
// COMPLETE COOK-TORRANCE BRDF
// ============================================================================
// Main BRDF function combining all terms

vec3 cookTorranceBRDF(
	vec3 normal,
	vec3 viewDir,
	vec3 lightDir,
	vec3 albedo,
	float roughness,
	float metallic,
	out float specular
) {
	// Normalize directions
	vec3 V = normalize(viewDir);
	vec3 L = normalize(lightDir);
	vec3 N = normalize(normal);
	vec3 H = normalize(V + L);

	float nDotL = max(dot(N, L), 0.0);
	float nDotV = max(dot(N, V), 0.0);

	// Fresnel F0 depends on metallic
	vec3 f0 = mix(vec3(0.04), albedo, metallic);

	// Fresnel term
	vec3 F = fresnelSchlickVec(max(dot(H, V), 0.0), f0);

	// Distribution term
	float D = distributionGGX(N, H, roughness);

	// Geometry term (height-correlated for better quality)
	float G = geometrySmithHeightCorrelated(N, V, L, roughness);

	// Specular component: (D * F * G) / (4 * (N·V) * (N·L))
	vec3 specularBRDF = (D * F * G) / max(4.0 * nDotV * nDotL, 0.001);

	// Diffuse (Lambertian) component
	vec3 kS = F;           // Specular contribution
	vec3 kD = vec3(1.0) - kS;  // Diffuse contribution
	kD *= (1.0 - metallic);    // Metals have no diffuse

	vec3 diffuseBRDF = kD * albedo / 3.14159265;

	specular = dot(F, vec3(0.299, 0.587, 0.114));  // Convert to grayscale

	return (diffuseBRDF + specularBRDF) * nDotL;
}

// ============================================================================
// MULTI-SCATTER COMPENSATION
// ============================================================================
// Energy compensation for multiple bounces on rough surfaces
// Reference: Complementary Shaders multi-scatter implementation

vec3 multiScatterCompensation(vec3 color, float roughness) {
	// Rougher surfaces lose more energy to multiple bounces
	// This compensates to maintain energy conservation
	float brightnessFade = clamp(1.0 - roughness * 0.5, 0.0, 1.0);
	return mix(color, vec3(0.5), 1.0 - brightnessFade);
}

#endif
