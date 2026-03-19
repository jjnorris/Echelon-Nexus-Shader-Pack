// ===================================================================
// Spherical Harmonics (Phase 20)
// ===================================================================
// SH encoding and decoding for efficient IBL representation.

#ifndef INCLUDE_SPHERICAL_HARMONICS
#define INCLUDE_SPHERICAL_HARMONICS

// ===================================================================
// SPHERICAL HARMONIC BASIS FUNCTIONS
// ===================================================================

// Compute SH basis functions (first 9 bands, L2 complexity)
vec4 sh_basis0(vec3 direction) {
    // L0: constant
    return vec4(0.282095, 0.0, 0.0, 0.0);
}

vec4 sh_basis1(vec3 direction) {
    // L1: linear (3 terms)
    return vec4(0.488603 * direction.z,
                0.488603 * direction.x,
                0.488603 * direction.y,
                0.0);
}

vec4 sh_basis2(vec3 direction) {
    // L2: quadratic (5 terms)
    return vec4(1.092548 * direction.x * direction.z,
                1.092548 * direction.y * direction.z,
                0.315392 * (3.0 * direction.y * direction.y - 1.0),
                1.092548 * direction.x * direction.y);
}

// ===================================================================
// SH PROJECTION
// ===================================================================

// Project radiance onto SH basis
struct SHCoefficients {
    vec3 c0;  // L0 band
    vec3 c1[3]; // L1 band (3 coefficients)
    vec3 c2[5]; // L2 band (5 coefficients)
};

SHCoefficients projectToSH(vec3 direction, vec3 radiance) {
    SHCoefficients coeff;

    // Project onto L0
    coeff.c0 = radiance * 0.282095;

    // Project onto L1 (3 coefficients)
    coeff.c1[0] = radiance * 0.488603 * direction.z;
    coeff.c1[1] = radiance * 0.488603 * direction.x;
    coeff.c1[2] = radiance * 0.488603 * direction.y;

    // Project onto L2 (5 coefficients)
    coeff.c2[0] = radiance * 1.092548 * direction.x * direction.z;
    coeff.c2[1] = radiance * 1.092548 * direction.y * direction.z;
    coeff.c2[2] = radiance * 0.315392 * (3.0 * direction.y * direction.y - 1.0);
    coeff.c2[3] = radiance * 1.092548 * direction.x * direction.y;
    coeff.c2[4] = radiance * 0.546274 * (direction.x * direction.x - direction.y * direction.y);

    return coeff;
}

// ===================================================================
// SH EVALUATION
// ===================================================================

// Evaluate SH coefficients for given direction
vec3 evaluateSH(vec3 direction, SHCoefficients coeff) {
    vec3 result = vec3(0.0);

    // L0
    result += coeff.c0 * 0.282095;

    // L1
    result += coeff.c1[0] * (0.488603 * direction.z);
    result += coeff.c1[1] * (0.488603 * direction.x);
    result += coeff.c1[2] * (0.488603 * direction.y);

    // L2
    result += coeff.c2[0] * (1.092548 * direction.x * direction.z);
    result += coeff.c2[1] * (1.092548 * direction.y * direction.z);
    result += coeff.c2[2] * (0.315392 * (3.0 * direction.y * direction.y - 1.0));
    result += coeff.c2[3] * (1.092548 * direction.x * direction.y);
    result += coeff.c2[4] * (0.546274 * (direction.x * direction.x - direction.y * direction.y));

    return max(vec3(0.0), result);
}

// ===================================================================
// SH ROTATION
// ===================================================================

// Rotate SH coefficients (simple approximation for small rotations)
SHCoefficients rotateSH(SHCoefficients coeff, mat3 rotation) {
    // Rotate L0 (invariant)
    SHCoefficients rotated = coeff;

    // Rotate L1 (simple 3D vector rotation)
    vec3 l1_0 = vec3(coeff.c1[0].x, 0.0, 0.0);
    vec3 l1_1 = vec3(0.0, coeff.c1[1].x, 0.0);
    vec3 l1_2 = vec3(0.0, 0.0, coeff.c1[2].x);

    rotated.c1[0] = rotation * l1_0;
    rotated.c1[1] = rotation * l1_1;
    rotated.c1[2] = rotation * l1_2;

    // L2 rotation would be more complex (matrix form)
    // For simplicity, skip L2 rotation or use approximation

    return rotated;
}

// ===================================================================
// SH AVERAGING
// ===================================================================

// Average multiple SH coefficients (for dynamic lighting updates)
SHCoefficients averageSH(SHCoefficients coeffs[4]) {
    SHCoefficients avg;

    avg.c0 = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        avg.c1[i] = vec3(0.0);
        avg.c2[i] = vec3(0.0);
    }
    avg.c2[3] = vec3(0.0);
    avg.c2[4] = vec3(0.0);

    for (int j = 0; j < 4; j++) {
        avg.c0 += coeffs[j].c0;
        for (int i = 0; i < 3; i++) {
            avg.c1[i] += coeffs[j].c1[i];
        }
        for (int i = 0; i < 5; i++) {
            avg.c2[i] += coeffs[j].c2[i];
        }
    }

    avg.c0 *= 0.25;
    for (int i = 0; i < 3; i++) {
        avg.c1[i] *= 0.25;
    }
    for (int i = 0; i < 5; i++) {
        avg.c2[i] *= 0.25;
    }

    return avg;
}

#endif // INCLUDE_SPHERICAL_HARMONICS
