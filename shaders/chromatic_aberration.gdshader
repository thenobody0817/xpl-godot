// Port of QianMo/X-PostProcessing-Library -> Shaders/XPostProcessing.hlsl : ChromaticAberration()
// Radial RGB split, displacing channels along the vector from the sampled uv to screen centre.

shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/xpl_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount : hint_range(0.0, 40.0) = 4.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	// SCREEN_PIXEL_SIZE == 1.0 / screen resolution, i.e. texelSize in the original.
	COLOR = vec4(chromatic_aberration(screen_tex, SCREEN_PIXEL_SIZE, uv, amount), 1.0);
}