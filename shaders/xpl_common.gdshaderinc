// ---------------------------------------------------------------------------
// xpl_common.gdshaderinc
//
// Portable subset of QianMo/X-PostProcessing-Library's Shaders/XPostProcessing.hlsl,
// translated from HLSL to Godot's shading language.
//
// Dropped as Unity-specific: unity_CameraProjection / unity_OrthoParams /
// UNITY_BRANCH / stereo handling / DownsampleBox4Tap / TransformTriangleVertexToUV.
// Everything below is pure math and ports verbatim.
// ---------------------------------------------------------------------------

// ---- hash / noise -------------------------------------------------------

float rand1(float n) {
	return fract(sin(n) * 13758.5453123 * 0.01);
}

float rand2(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
}

// Godot has no texture-based noise asset here, so RGBSplitV5's _NoiseTex lookup
// becomes this hash. Channel-wise falloff reproduces the original's 4-tap LUT feel.
vec4 noise4(vec2 p) {
	return vec4(rand2(p), rand2(p + vec2(17.13, 3.71)), rand2(p + vec2(3.71, 17.13)), rand2(p + vec2(7.23, 7.23)));
}

// ---- colour -------------------------------------------------------------

float luminance_v1(vec3 c) {
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11;
}

float luminance_v2(vec3 c) {
	return dot(c, vec3(0.222, 0.707, 0.071));
}

// ---- uv transforms ------------------------------------------------------

vec2 rotate_uv(vec2 uv, float rotation) {
	float cosine = cos(rotation);
	float sine = sin(rotation);
	vec2 pivot = vec2(0.5, 0.5);
	mat2 rotator = mat2(vec2(cosine, -sine), vec2(sine, cosine));
	return clamp(rotator * (uv - pivot) + pivot, vec2(0.0), vec2(1.0));
}

vec2 fisheye_uv(vec2 uv, float amount, float zoom) {
	vec2 center = uv - vec2(0.5, 0.5);
	float CdotC = dot(center, center);
	float f = 1.0 + CdotC * (amount * sqrt(CdotC));
	return f * zoom * center + vec2(0.5, 0.5);
}

// Radial chromatic aberration, sampling `tex` around the screen centre.
vec3 chromatic_aberration(sampler2D tex, vec2 texel_size, vec2 uv, float amount) {
	vec2 direction = normalize(vec2(0.5, 0.5) - uv);
	vec3 distortion = vec3(-texel_size.x * amount, 0.0, texel_size.x * amount);

	float red = texture(tex, uv + direction * distortion.r).r;
	float green = texture(tex, uv + direction * distortion.g).g;
	float blue = texture(tex, uv + direction * distortion.b).b;
	return vec3(red, green, blue);
}

// ---- waves --------------------------------------------------------------

float sinusoid_wave(float len, float pi_, float time_) {
	float wave = sin(8.0 * pi_ * len + time_);
	wave = 0.5 * wave + 0.2;
	return wave * wave * wave;
}

// ---------------------------------------------------------------------------
// Blend operations — ported from XPostProcessing.hlsl. `Base` is the already
// rendered frame, `Blend` is the effect colour. All return mix(Base, Out, Opacity).
// ---------------------------------------------------------------------------

vec4 blend_burn(vec4 b, vec4 bl, float o) { return mix(b, vec4(1.0) - (vec4(1.0) - bl) / b, o); }
vec4 blend_darken(vec4 b, vec4 bl, float o) { return mix(b, min(bl, b), o); }
vec4 blend_difference(vec4 b, vec4 bl, float o) { return mix(b, abs(bl - b), o); }
vec4 blend_dodge(vec4 b, vec4 bl, float o) { return mix(b, b / (vec4(1.0) - bl), o); }
vec4 blend_divide(vec4 b, vec4 bl, float o) { return mix(b, b / (bl + vec4(0.000000000001)), o); }
vec4 blend_exclusion(vec4 b, vec4 bl, float o) { return mix(b, bl + b - (vec4(2.0) * bl * b), o); }
vec4 blend_lighten(vec4 b, vec4 bl, float o) { return mix(b, max(bl, b), o); }
vec4 blend_linear_burn(vec4 b, vec4 bl, float o) { return mix(b, b + bl - vec4(1.0), o); }
vec4 blend_linear_dodge(vec4 b, vec4 bl, float o) { return mix(b, b + bl, o); }
vec4 blend_multiply(vec4 b, vec4 bl, float o) { return mix(b, b * bl, o); }
vec4 blend_negation(vec4 b, vec4 bl, float o) { return mix(b, vec4(1.0) - abs(vec4(1.0) - bl - b), o); }
vec4 blend_screen(vec4 b, vec4 bl, float o) { return mix(b, vec4(1.0) - (vec4(1.0) - bl) * (vec4(1.0) - b), o); }
vec4 blend_subtract(vec4 b, vec4 bl, float o) { return mix(b, b - bl, o); }
vec4 blend_overwrite(vec4 b, vec4 bl, float o) { return mix(b, bl, o); }
vec4 blend_hard_mix(vec4 b, vec4 bl, float o) { return mix(b, step(vec4(1.0) - b, bl), o); }

vec4 blend_hard_light(vec4 b, vec4 bl, float o) {
	vec4 r1 = vec4(1.0) - vec4(2.0) * (vec4(1.0) - b) * (vec4(1.0) - bl);
	vec4 r2 = vec4(2.0) * b * bl;
	vec4 z = step(bl, vec4(0.5));
	return mix(b, r2 * z + (vec4(1.0) - z) * r1, o);
}

vec4 blend_overlay(vec4 b, vec4 bl, float o) {
	vec4 r1 = vec4(1.0) - vec4(2.0) * (vec4(1.0) - b) * (vec4(1.0) - bl);
	vec4 r2 = vec4(2.0) * b * bl;
	vec4 z = step(b, vec4(0.5));
	return mix(b, r2 * z + (vec4(1.0) - z) * r1, o);
}

vec4 blend_soft_light(vec4 b, vec4 bl, float o) {
	vec4 r1 = vec4(2.0) * b * bl + b * b * (vec4(1.0) - vec4(2.0) * bl);
	vec4 r2 = sqrt(b) * (vec4(2.0) * bl - vec4(1.0)) + vec4(2.0) * b * (vec4(1.0) - bl);
	vec4 z = step(vec4(0.5), bl);
	return mix(b, r2 * z + (vec4(1.0) - z) * r1, o);
}

vec4 blend_soft_light_v2(vec4 b, vec4 bl, float o) {
	vec4 r1 = b * (bl + vec4(2.0)) - vec4(2.0);
	vec4 r2 = vec4(1.0) - (vec4(2.0) - b) * (vec4(1.0) - bl);
	vec4 z = step(vec4(0.5), bl);
	return mix(b, r2 * z + (vec4(1.0) - z) * r1, o);
}

vec4 blend_pin_light(vec4 b, vec4 bl, float o) {
	vec4 check = step(vec4(0.5), bl);
	vec4 r1 = check * max(vec4(2.0) * (b - vec4(0.5)), bl);
	return mix(b, r1 + (vec4(1.0) - check) * min(vec4(2.0) * b, bl), o);
}

vec4 blend_vivid_light(vec4 b, vec4 bl, float o) {
	vec4 r1 = vec4(1.0) - (vec4(1.0) - bl) / (vec4(2.0) * b);
	vec4 r2 = bl / (vec4(2.0) * (vec4(1.0) - b));
	vec4 z = step(vec4(0.5), b);
	return mix(b, r2 * z + (vec4(1.0) - z) * r1, o);
}

vec4 blend_linear_light(vec4 b, vec4 bl, float o) {
	vec4 low = max(b + (vec4(2.0) * bl) - vec4(1.0), vec4(0.0));
	vec4 high = min(b + vec4(2.0) * (bl - vec4(0.5)), vec4(1.0));
	return mix(b, mix(low, high, step(vec4(0.5), bl)), o);
}

vec4 blend_linear_light_add_sub(vec4 b, vec4 bl, float o) {
	return mix(b, bl + vec4(2.0) * b - vec4(1.0), o);
}

// Dispatch table: `mode` indexes the 23 BlendOperation_* functions in the order
// they appear in XPostProcessing.hlsl. Keeping one entry point lets a single
// effect shader expose "blend mode" as a dropdown instead of 23 shaders.
vec4 blend_operation(int mode, vec4 b, vec4 bl, float o) {
	if (mode == 0)  { return blend_burn(b, bl, o); }
	if (mode == 1)  { return blend_darken(b, bl, o); }
	if (mode == 2)  { return blend_difference(b, bl, o); }
	if (mode == 3)  { return blend_dodge(b, bl, o); }
	if (mode == 4)  { return blend_divide(b, bl, o); }
	if (mode == 5)  { return blend_exclusion(b, bl, o); }
	if (mode == 6)  { return blend_hard_light(b, bl, o); }
	if (mode == 7)  { return blend_hard_mix(b, bl, o); }
	if (mode == 8)  { return blend_lighten(b, bl, o); }
	if (mode == 9)  { return blend_linear_burn(b, bl, o); }
	if (mode == 10) { return blend_linear_dodge(b, bl, o); }
	if (mode == 11) { return blend_linear_light(b, bl, o); }
	if (mode == 12) { return blend_linear_light_add_sub(b, bl, o); }
	if (mode == 13) { return blend_multiply(b, bl, o); }
	if (mode == 14) { return blend_negation(b, bl, o); }
	if (mode == 15) { return blend_overlay(b, bl, o); }
	if (mode == 16) { return blend_pin_light(b, bl, o); }
	if (mode == 17) { return blend_screen(b, bl, o); }
	if (mode == 18) { return blend_soft_light(b, bl, o); }
	if (mode == 19) { return blend_soft_light_v2(b, bl, o); }
	if (mode == 20) { return blend_subtract(b, bl, o); }
	if (mode == 21) { return blend_vivid_light(b, bl, o); }
	return blend_overwrite(b, bl, o);
}

const int XPL_BLEND_MODE_COUNT = 23;