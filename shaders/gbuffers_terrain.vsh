#version 130

// GBUFFERS_TERRAIN VERTEX SHADER - Phase 1 Foundation
//
// References:
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4/blob/main/shaders/gbuffers_terrain.vsh
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial
//
// Purpose: Render terrain blocks with full material properties and lighting
// Supports normal maps, PBR materials, and displacement

#define OVERWORLD
#define VSH
#include "/program/gbuffers_terrain.glsl"
