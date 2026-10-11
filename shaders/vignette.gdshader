// Port of QianMo/X-PostProcessing-Library -> Effects/RapidVignette
// Frag_ColorAdjust(): falloff is a plain squared distance from _VignetteCenter,
// so it's a circular vignette that doesn't respect screen aspect. _vignetteCenter
// is the offset of uv from centre; here we fold the softness into the falloff so
// the control feels linear rather than 1/(d^2).

shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/xpl_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount : hint_range(0.0, 2.0) = 0.6;
uniform float softness : hint_range(0.01, 1.5) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool tint = true;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 final_color = texture(screen_tex, uv);

	// upstream: saturate(1 - dot(offset, offset) * intensity), offset = uv - center
	float d2 = dot(uv - vec2(0.5), uv - vec2(0.5));
	float intensity = clamp(1.0 - d2 * amount, 0.0, 1.0);

	// stretch the falloff by softness, keeping intensity==1 near the centre
	intensity = pow(intensity, softness * 2.0);

	if (tint) {
		// upstream Frag_ColorAdjust
		final_color.rgb = mix(vignette_color.rgb, final_color.rgb, intensity);
		final_color.a = vignette_color.a;
	} else {
		// upstream Frag
		final_color *= intensity;
	}

	COLOR = final_color;
}