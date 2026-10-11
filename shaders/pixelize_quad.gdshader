// Port of QianMo/X-PostProcessing-Library -> Effects/PixelizeQuad
// Original RectPixelizeUV(): snaps uv to a grid whose cell is pixel_size, with an
// independent x/y aspect driven by pixel_scale_x and pixel_ratio.

shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/xpl_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 80.0) = 14.0;
uniform float pixel_ratio : hint_range(0.25, 4.0) = 1.0;

vec2 rect_pixelize_uv(vec2 uv) {
	float pixel_scale = 1.0 / pixel_size;
	// upstream has separate _PixelScaleX/_PixelScaleY; here the x axis uses the
	// pixel size directly and y folds in pixel_ratio for aspect correction.
	return vec2(
		pixel_scale * floor(uv.x / pixel_scale),
		(pixel_scale * pixel_ratio) * floor(uv.y / (pixel_scale * pixel_ratio))
	);
}

void fragment() {
	COLOR = texture(screen_tex, rect_pixelize_uv(SCREEN_UV));
}