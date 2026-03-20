#version 130

// COMPOSITE FRAGMENT SHADER - Phase 1 Foundation
//
// Reference:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/composite.fsh
// - Complementary Shaders: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Apply shadows and basic lighting to G-Buffer
// This is the main lighting pass that brings the scene to life

#define OVERWORLD
#define FSH
#include "/program/composite.glsl"
