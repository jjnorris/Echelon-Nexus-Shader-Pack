#version 130

// SHADOW FRAGMENT SHADER - Phase 1 Foundation
//
// Reference Implementation:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/shadow.fsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Render shadow color data and depth from sun perspective
// Outputs shadowcolor0 (depth map) and shadowcolor1 (colored shadow data)

#define OVERWORLD
#define FSH
#include "/program/shadow.glsl"
