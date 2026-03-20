#version 400 compatibility

uniform sampler2D gtexture;

out vec2 uv;
out vec4 tint;

void main() {
	uv = gl_MultiTexCoord0.xy;
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}
