// Port of QianMo/X-PostProcessing-Library -> Effects/GlitchImageBlockV4
//
// Upstream displaces whole quantised blocks and splits RGB along the same offset.
// The block displacement is scaled by a per-block noise (noiseX/noiseY) so blocks
// move in varying directions rather than uniformly.

shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/xpl_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float speed : hint_range(0.0, 30.0) = 8.0;
uniform float block_size : hint_range(1.0, 80.0) = 18.0;
uniform float rgb_split : hint_range(0.0, 0.5) = 0.08;

float random_noise(vec2 seed) {
	return fract(sin(dot(seed * floor(TIME * speed), vec2(17.13, 3.71))) * 43758.5453123);
}

float random_noise1(float seed) {
	return random_noise(vec2(seed, 1.0));
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// upstream writes `half2 block = randomNoise(...)` — HLSL splats the returned
	// float across x/y implicitly. Only .x is ever read, so a plain float is
	// equivalent and Godot has no implicit splat.
	float block = random_noise(floor(uv * block_size));
	float displace_noise = pow(block, 8.0) * pow(block, 3.0);
	float split_rgb_noise = pow(random_noise1(7.2341), 17.0);

	float offset_x = displace_noise - split_rgb_noise * rgb_split;
	float offset_y = displace_noise - split_rgb_noise * rgb_split;

	float noise_x = 0.05 * random_noise1(13.0);
	float noise_y = 0.05 * random_noise1(7.0);
	vec2 offset = vec2(offset_x * noise_x, offset_y * noise_y);

	vec4 color_r = texture(screen_tex, uv);
	vec4 color_g = texture(screen_tex, uv + offset);
	vec4 color_b = texture(screen_tex, uv - offset);

	COLOR = vec4(color_r.r, color_g.g, color_b.b, (color_r.a + color_g.a + color_b.a));
}