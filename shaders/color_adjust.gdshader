// Blend of QianMo/X-PostProcessing-Library effects:
//   Effects/ColorAdjustmentContrastV3, ColorAdjustmentSaturation, ColorAdjustmentBrightness
// plus the 23 BlendOperation_* helpers from Shaders/XPostProcessing.hlsl.
//
// Contrast V3:  out = (in - factor) * contrast + factor,  with contrast = 1 - _Contrast.w

shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/xpl_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float contrast : hint_range(-1.0, 2.0) = 0.35;
uniform float saturation : hint_range(0.0, 3.0) = 1.3;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform int blend_mode : hint_range(0, 22) = 0;
uniform float blend_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 blend_color : source_color = vec4(1.0, 0.2, 0.6, 1.0);

void fragment() {
	vec4 base = texture(screen_tex, SCREEN_UV);
	vec3 c = base.rgb;

	// --- Contrast V3 (per-channel pivot 0.5) ---
	vec3 factor = vec3(0.5);
	c = (c - factor) * (1.0 - contrast) + factor;

	// --- Brightness ---
	c += brightness;

	// --- Saturation (luma_v1 weighting, as upstream) ---
	float luma = luminance_v1(c);
	c = mix(vec3(luma), c, saturation);

	vec4 graded = vec4(c, base.a);

	// Blend layer. blend_operation() already lerps toward its result by
	// blend_opacity, so opacity 0 passes the grade through untouched and
	// raising it crossfades in blend_color under the chosen blend mode.
	COLOR = blend_operation(blend_mode, graded, blend_color, blend_opacity);
}