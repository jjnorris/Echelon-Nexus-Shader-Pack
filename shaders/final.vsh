#version 130

// FINAL VERTEX SHADER - Phase 1 Foundation
//
// Reference: https://github.com/ComplementaryDevelopment/ComplementaryShadersV4
//
// Purpose: Simple full-screen quad for final post-processing
// Renders directly to screen after all deferred passes

varying vec2 texCoord;

void main() {
	gl_Position = gl_Vertex;
	texCoord = gl_MultiTexCoord0.xy;
}
