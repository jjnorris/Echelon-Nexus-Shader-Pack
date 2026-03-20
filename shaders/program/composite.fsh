// ============================================================================
// COMPOSITE FRAGMENT SHADER - Phase 1 (DEBUG VERSION)
// ============================================================================
//
// Testing G-Buffer output - simple pass-through of albedo

varying vec2 texCoord;

uniform sampler2D gcolor;       // Albedo + AO
uniform sampler2D gdepth;       // Linear depth
uniform sampler2D gnormal;      // Normal + smoothness
uniform sampler2D gaux1;        // Material

void main() {
	// DEBUG: Just output the raw G-Buffer color
	// This will show us if G-Buffer is being populated at all
	vec4 albedo = texture2D(gcolor, texCoord);

	// If G-Buffer is empty, this will be black (0,0,0,0)
	// If G-Buffer has data, we should see the actual terrain colors
	gl_FragColor = vec4(albedo.rgb, 1.0);

	// Amplify slightly to see if there's any data
	gl_FragColor.rgb *= 2.0;
}
