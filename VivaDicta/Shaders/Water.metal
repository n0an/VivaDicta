//
// Water.metal
// VivaDicta
//

#include <metal_stdlib>
using namespace metal;

/// A shader that generates a water ripple distortion effect.
///
/// - Parameter position: The user-space coordinate of the current pixel.
/// - Parameter size: The size of the whole image, in user-space.
/// - Parameter time: The number of elapsed seconds since the shader was created.
/// - Parameter speed: How fast to make the water ripple.
/// - Parameter strength: How pronounced the rippling effect should be.
/// - Parameter frequency: How often ripples should be created.
/// - Returns: The distorted position.
[[ stitchable ]] float2 water(float2 position, float2 size, float time, float speed, float strength, float frequency) {
    float2 uv = position / size;

    float adjustedSpeed = time * speed * 0.05f;
    float adjustedStrength = strength / 100.0f;

    // Wrap the phase so sin/cos never see huge arguments
    const float TWO_PI = 6.28318530718f;
    float phase = fmod(adjustedSpeed * frequency, TWO_PI);

    float argX = frequency * uv.x + phase;
    float argY = frequency * uv.y + phase;
    uv.x += fast::sin(argX) * adjustedStrength;
    uv.y += fast::cos(argY) * adjustedStrength;

    return uv * size;
}
