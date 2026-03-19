#version 330 compatibility

in vec3 vaPosition;
in vec3 vaNormal;
in vec2 vaTexCoord;
in vec4 vaColor;

out vec3 vPosition;
out vec3 vNormal;
out vec2 vTexCoord;
out vec4 vColor;

void main() {
    vPosition = vaPosition;
    vNormal = vaNormal;
    vTexCoord = vaTexCoord;
    vColor = vaColor;
    gl_Position = gl_ModelViewProjectionMatrix * vec4(vaPosition, 1.0);
}
