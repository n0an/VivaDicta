//
// Wave.metal
// VivaDicta
//

#include <metal_stdlib>
using namespace metal;

/// A shader that generates a uniform wave distortion effect.
///
/// - Parameter position: The user-space coordinate of the current pixel.
/// - Parameter time: The number of elapsed seconds since the shader was created.
/// - Parameter speed: How fast to make the waves ripple.
/// - Parameter smoothing: How smooth the ripples are.
/// - Parameter strength: How pronounced the effect is.
/// - Returns: The distorted position.
[[ stitchable ]] float2 wave(float2 position, float time, float speed, float smoothing, float strength) {
    position.y += sin(time * speed + position.x / smoothing) * strength;
    return position;
}
