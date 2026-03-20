#version 400 compatibility

/* PHASE 2: PCSS SHADOWS COMPOSITE PASS
   Vertex shader - simple screen-quad rendering
*/

out vec2 uv;

void main() {
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
	uv = gl_MultiTexCoord0.xy;
}
