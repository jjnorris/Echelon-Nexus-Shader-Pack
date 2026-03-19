// Minimal shared utilities
#ifndef INCLUDE_COMMON
#define INCLUDE_COMMON

// Constants
const float PI = 3.14159265;
const float TWO_PI = 6.28318530;
const float HALF_PI = 1.57079632;
const float EPSILON = 1e-5;

// Octahedral encoding for normals
vec2 encodeNormal(vec3 n) {
    float l1norm = abs(n.x) + abs(n.y) + abs(n.z);
    vec2 uv = n.xy / l1norm;
    if (n.z < 0.0) {
        float oldU = uv.x;
        uv.x = (1.0 - abs(uv.y)) * (oldU >= 0.0 ? 1.0 : -1.0);
        uv.y = (1.0 - abs(oldU)) * (uv.y >= 0.0 ? 1.0 : -1.0);
    }
    return uv * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec3 v = vec3(uv.x, uv.y, 1.0 - abs(uv.x) - abs(uv.y));
    if (v.z < 0.0) {
        float oldX = v.x;
        v.x = (1.0 - abs(v.y)) * (oldX >= 0.0 ? 1.0 : -1.0);
        v.y = (1.0 - abs(oldX)) * (v.y >= 0.0 ? 1.0 : -1.0);
    }
    return normalize(v);
}

#endif
