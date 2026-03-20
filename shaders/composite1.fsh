#version 130

// COMPOSITE1 FRAGMENT SHADER - Phase 2: PCSS Shadows
//
// Reference:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
// - Photon Shaders: https://github.com/sixthsurge/photon
//
// Purpose: Percentage-Closer Soft Shadows with blocker search and penumbra estimation

#define OVERWORLD
#define FSH
#include "/program/composite1.glsl"
