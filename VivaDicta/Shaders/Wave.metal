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

/// A shader that creates a fluid water ripple distortion effect.
/// Uses both sine and cosine for bidirectional wave movement.
///
/// - Parameter position: The user-space coordinate of the current pixel.
/// - Parameter size: The size of the view being distorted.
/// - Parameter time: The number of elapsed seconds since the shader was created.
/// - Parameter speed: How fast the water ripples move.
/// - Parameter strength: How pronounced the distortion effect is.
/// - Parameter frequency: How many ripples appear across the view.
/// - Returns: The distorted position creating a water-like effect.
[[ stitchable ]] float2 water(float2 position, float2 size, float time, float speed, float strength, float frequency) {
    half2 uv = half2(position / size);

    half adjustedSpeed = time * speed * 0.05h;
    half adjustedStrength = strength / 100.0h;

    uv.x += sin((uv.x + adjustedSpeed) * frequency) * adjustedStrength;
    uv.y += cos((uv.y + adjustedSpeed) * frequency) * adjustedStrength;

    return float2(uv) * size;
}

/// A color shader that creates an animated grayscale gradient sweep effect.
/// Produces a wave of brightness that moves across the view.
///
/// - Parameter position: The user-space coordinate of the current pixel.
/// - Parameter color: The current color of the pixel.
/// - Parameter size: The size of the view being colored.
/// - Parameter timeOffset: Animation progress from 0 to 1 controlling the sweep position.
/// - Returns: The modified color with grayscale gradient applied.
[[ stitchable ]] half4 grayscaleGradient(float2 position, half4 color, float2 size, float timeOffset) {
    position.x *= size.x / 1200;
    float2 uv = position / size;
    float t = uv.x - timeOffset;

    half angle = t * 6.28318h;
    half3 newColor = half3(sin(angle));

    return half4(newColor * 0.5h + 0.75h, 1.0h) * color.a;
}
