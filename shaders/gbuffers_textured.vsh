#version 130

// GBUFFERS_TEXTURED VERTEX SHADER - Phase 1 Foundation
//
// Reference Implementations:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/gbuffers_textured.vsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4/tree/main/shaders
//
// Purpose: G-Buffer pass for textured geometry (blocks, entities)
// Renders material properties and depth for deferred lighting

#include "/program/gbuffers_textured.vsh"
