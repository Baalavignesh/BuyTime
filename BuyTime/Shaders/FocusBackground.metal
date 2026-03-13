//
//  FocusBackground.metal
//  BuyTime
//
//  Ripple Gradient Effect — concentric rings from multiple SDF sources
//  with smooth interference and organic motion.
//

#include <metal_stdlib>
using namespace metal;

// --- Signed Distance Functions ---

float circleSDF(float2 point, float2 center, float radius) {
    return length(point - center) - radius;
}

// Smooth minimum blends two distance fields organically
float smoothMin(float d1, float d2, float k) {
    float h = max(k - abs(d1 - d2), 0.0) / k;
    return min(d1, d2) - h * h * k * 0.25;
}

// --- Shader entry point ---

[[ stitchable ]] half4 focusBackground(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float boost
) {
    // Normalize to UV space, correct for aspect ratio
    float2 uv = position / size;
    float aspect = size.x / size.y;
    float2 st = float2((uv.x - 0.5) * aspect, uv.y - 0.5);

    float t = time * 0.12;  // Slow, calm motion

    // --- Define ripple sources with gentle orbital motion ---
    // 4 core sources always active; 4 extra activate when expanded (boost > 1.0)

    bool expanded = boost > 1.05;

    float2 sources[8];
    sources[0] = float2( sin(t * 0.7) * 0.15,   cos(t * 0.5) * 0.12);
    sources[1] = float2( cos(t * 0.4) * 0.25,  -sin(t * 0.6) * 0.18);
    sources[2] = float2(-sin(t * 0.3) * 0.20,   sin(t * 0.8) * 0.14);
    sources[3] = float2( cos(t * 0.5) * 0.10,  -cos(t * 0.4) * 0.22);
    // Expanded-only sources — wider orbits to fill the full screen
    sources[4] = float2(-cos(t * 0.6) * 0.32,   sin(t * 0.35) * 0.28);
    sources[5] = float2( sin(t * 0.45) * 0.28, -cos(t * 0.55) * 0.34);
    sources[6] = float2(-sin(t * 0.55) * 0.18,  -cos(t * 0.7) * 0.30);
    sources[7] = float2( cos(t * 0.35) * 0.35,   sin(t * 0.45) * 0.20);

    int sourceCount = expanded ? 8 : 4;

    // --- Build ripple field from SDF distances ---

    // Blend all source distances using smooth minimum
    // This creates organic interference where ripples merge
    float blendedDist = circleSDF(st, sources[0], 0.0);
    for (int i = 1; i < sourceCount; i++) {
        float d = circleSDF(st, sources[i], 0.0);
        blendedDist = smoothMin(blendedDist, d, 0.4);
    }

    // Create concentric ripples from the blended distance field
    // Expanded: higher frequency = tighter, thinner rings with more dark between them
    float rippleFreq = expanded ? 28.0 : 12.0;
    float rippleSpeed = t * 3.0;
    float ripple = sin(blendedDist * rippleFreq - rippleSpeed);

    // Expanded: narrower smoothstep band = thinner bright lines, more dark
    float edgeSoft = expanded ? 0.15 : 0.3;
    float wave = smoothstep(-edgeSoft, edgeSoft, ripple);

    // Second harmonic at different frequency for depth
    float ripple2 = sin(blendedDist * (rippleFreq * 0.6) + rippleSpeed * 0.5);
    float wave2 = smoothstep(-edgeSoft * 1.3, edgeSoft * 1.3, ripple2);

    // Combine waves with the second as subtle overlay
    float combined = mix(wave, wave2, 0.25);

    // --- Distance-based fade: ripples dim further from sources ---
    // Expanded: steeper fade so ripples are more localized around sources
    float fadeEnd = expanded ? 0.40 : 0.55;
    float fade = 1.0 - smoothstep(0.05, fadeEnd, blendedDist);

    // --- Brightness mapping ---
    // Expanded: lower peak brightness = more dark overall, subtle fine lines
    float baseBright = 0.012;
    float peakBright = expanded ? 0.08 : 0.11;
    float brightness = mix(baseBright, peakBright, combined * fade);

    // Add a faint glow near ripple sources
    float glowIntensity = expanded ? 0.04 : 0.06;
    float glow = exp(-blendedDist * blendedDist * 18.0) * glowIntensity;
    brightness += glow;

    // --- Radial vignette ---
    // Expanded: stronger vignette pushes edges darker
    float vigStrength = expanded ? 1.2 : 0.8;
    float2 vc = uv - 0.5;
    float vig = 1.0 - dot(vc, vc) * vigStrength;
    brightness *= max(vig, 0.0);

    return half4(half3(brightness), 1.0);
}
