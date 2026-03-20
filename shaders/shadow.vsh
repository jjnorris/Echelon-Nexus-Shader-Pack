#version 130

// SHADOW VERTEX SHADER - Phase 1 Foundation
//
// Reference Implementation:
// - Shadow Tutorial: https://github.com/shaderLABS/Shadow-Tutorial/blob/main/shaders/shadow.vsh
// - OptiFine Doc: https://raw.githubusercontent.com/sp614x/optifine/master/OptiFineDoc/doc/shaders.txt
//
// Purpose: Transform vertices to shadow-space coordinates for depth map generation
// Renders world from sun perspective to create shadowtex0/shadowtex1 depth maps

// Include directive structure
#include "/program/shadow.vsh"
