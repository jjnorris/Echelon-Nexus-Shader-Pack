#version 400 compatibility

uniform sampler2D colortex0;

out vec2 uv;

void main() {
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
	uv = gl_MultiTexCoord0.xy;
}
