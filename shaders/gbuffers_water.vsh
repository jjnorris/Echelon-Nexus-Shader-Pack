#version 400 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;

out vec2 uv;
out vec2 light_levels;
out vec4 tint;

void main() {
	uv = gl_MultiTexCoord0.xy;
	light_levels = gl_MultiTexCoord1.xy / 240.0;
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}
