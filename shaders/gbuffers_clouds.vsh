#version 400 compatibility

out vec4 tint;

void main() {
	tint = gl_Color;
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}
