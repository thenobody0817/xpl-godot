// Port of QianMo/X-PostProcessing-Library -> Effects/GlitchRGBSplitV5
// Original: Assets/X-PostProcessing/Effects/GlitchRGBSplitV5/Shader/GlitchRGBSplitV5.shader
//
// Note: upstream samples a _NoiseTex LUT; here noise4() in the include hashes
// directly, so this shader needs no texture assets.

shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/xpl_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float amplitude : hint_range(0.0, 0.2) = 0.02;
uniform float speed : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// upstream: Pow4(Noise(...), 8.0) * float4(_Amplitude, _Amplitude, _Amplitude, 1.0)
	vec4 split_amount = pow(noise4(vec2(speed * TIME, 2.0 * speed * TIME / 25.0)), vec4(8.0))
		* vec4(amplitude, amplitude, amplitude, 1.0);

	// upstream: splitAmount *= 2.0 * splitAmount.w - 1.0
	split_amount *= 2.0 * split_amount.w - 1.0;

	float color_r = texture(screen_tex, uv + vec2(split_amount.x, -split_amount.y)).r;
	float color_g = texture(screen_tex, uv + vec2(split_amount.y, -split_amount.z)).g;
	float color_b = texture(screen_tex, uv + vec2(split_amount.z, -split_amount.x)).b;

	COLOR = vec4(color_r, color_g, color_b, 1.0);
}