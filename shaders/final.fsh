#version 400 compatibility

uniform sampler2D colortex0;

in vec2 uv;

void main() {
	vec3 color = texture(colortex0, uv).rgb;

	// Gamma correction (linear to sRGB)
	color = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));

	gl_FragColor = vec4(color, 1.0);
}
