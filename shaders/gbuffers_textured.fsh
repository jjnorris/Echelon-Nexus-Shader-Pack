#version 130

// GBUFFERS_TEXTURED FRAGMENT SHADER - Phase 1 Foundation
//
// Reference:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/gbuffers_textured.fsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Render textured geometry to G-Buffer for deferred lighting
// Outputs: Albedo, Depth, Normal, Material properties

#define OVERWORLD
#define FSH
#include "/program/gbuffers_textured.glsl"
