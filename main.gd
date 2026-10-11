extends Control
##
## XPL for Godot — demo harness.
##
## Architecture mirrors XPL's post-processing profile: a stack of fullscreen
## ColorRects, each running one effect shader and sampling `hint_screen_texture`.
## Because each ColorRect reads the buffer as of its own draw, they compose in
## tree order — so a pixelize layer below a blur layer gives blurred pixels.
##

# Order matches the `blend_operation` dispatch in shaders/xpl_common.gdshaderinc,
# which follows the BlendOperation_* sequence in XPostProcessing.hlsl.
const BLEND_MODES := [
	"Burn", "Darken", "Difference", "Dodge", "Divide", "Exclusion",
	"Hard Light", "Hard Mix", "Lighten", "Linear Burn", "Linear Dodge",
	"Linear Light", "Linear Light Add/Sub", "Multiply", "Negation",
	"Overlay", "Pin Light", "Screen", "Soft Light", "Soft Light V2",
	"Subtract", "Vivid Light", "Overwrite",
]

# Registry of ported effects. Adding one = drop a .gdshader in and add a row here.
const EFFECTS := [
	{
		"id": "color_adjust",
		"label": "Color Adjustment",
		"shader": "res://shaders/color_adjust.gdshader",
		"on": false,
		"params": [
			{"name": "contrast", "label": "Contrast", "min": -1.0, "max": 2.0, "default": 0.35},
			{"name": "saturation", "label": "Saturation", "min": 0.0, "max": 3.0, "default": 1.3},
			{"name": "brightness", "label": "Brightness", "min": -1.0, "max": 1.0, "default": 0.0},
			{"name": "blend_mode", "label": "Blend Mode", "options": BLEND_MODES},
			{"name": "blend_opacity", "label": "Blend Opacity", "min": 0.0, "max": 1.0, "default": 0.0},
		],
	},
	{
		"id": "chromatic",
		"label": "Chromatic Aberration",
		"shader": "res://shaders/chromatic_aberration.gdshader",
		"on": true,
		"params": [
			{"name": "amount", "label": "Amount", "min": 0.0, "max": 40.0, "default": 4.0},
		],
	},
	{
		"id": "pixelize",
		"label": "Pixelize Quad",
		"shader": "res://shaders/pixelize_quad.gdshader",
		"on": false,
		"params": [
			{"name": "pixel_size", "label": "Pixel Size", "min": 1.0, "max": 80.0, "default": 14.0},
			{"name": "pixel_ratio", "label": "Pixel Ratio", "min": 0.25, "max": 4.0, "default": 1.0},
		],
	},
	{
		"id": "vignette",
		"label": "Vignette",
		"shader": "res://shaders/vignette.gdshader",
		"on": false,
		"params": [
			{"name": "amount", "label": "Amount", "min": 0.0, "max": 2.0, "default": 0.6},
			{"name": "softness", "label": "Softness", "min": 0.01, "max": 1.5, "default": 0.45},
		],
	},
	{
		"id": "image_block",
		"label": "Glitch Image Block",
		"shader": "res://shaders/glitch_image_block.gdshader",
		"on": false,
		"params": [
			{"name": "speed", "label": "Speed", "min": 0.0, "max": 30.0, "default": 8.0},
			{"name": "block_size", "label": "Block Size", "min": 1.0, "max": 80.0, "default": 18.0},
			{"name": "rgb_split", "label": "RGB Split", "min": 0.0, "max": 0.5, "default": 0.08},
		],
	},
	{
		"id": "rgb_split",
		"label": "Glitch RGB Split",
		"shader": "res://shaders/glitch_rgb_split.gdshader",
		"on": true,
		"params": [
			{"name": "amplitude", "label": "Amplitude", "min": 0.0, "max": 0.1, "default": 0.015},
			{"name": "speed", "label": "Speed", "min": 0.0, "max": 10.0, "default": 1.5},
		],
	},
]

var _layers: Array[Dictionary] = []
var _t := 0.0
var _shot_path := ""
var _shot_frames := -1
var _hide_ui := false


func _ready() -> void:
	# Args must be parsed before the UI is built: --noui hides the panel during
	# construction, and --only decides the state the checkboxes are created with.
	var args := OS.get_cmdline_user_args()

	# `godot -- --shot [path]` renders a few frames, saves a PNG and exits.
	# Used for verifying effects without a human at the screen.
	var idx := args.find("--shot")
	if idx != -1:
		_shot_path = args[idx + 1] if idx + 1 < args.size() else "user://shot.png"
		_shot_frames = 0

	if args.has("--all"):
		for i in _layers.size():
			_layers[i]["on"] = true

	var only := args.find("--only")
	if only != -1 and only + 1 < args.size():
		var want := args[only + 1]
		for i in _layers.size():
			_layers[i]["on"] = _layers[i]["fx"]["id"] == want

	_hide_ui = args.has("--noui")

	_build_chain()
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

	if _shot_frames >= 0:
		_shot_frames += 1
		if _shot_frames == 10:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("SHOT ", ProjectSettings.globalize_path(_shot_path))
			get_tree().quit()


# ---------------------------------------------------------------------------
# Test pattern — deliberately spans fine detail (for pixelate/blur) and large
# flat colour areas (for grading/vignette), and animates so glitch reads clearly.
# ---------------------------------------------------------------------------

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var top := Color(0.09, 0.11, 0.16)
	var bot := Color(0.03, 0.03, 0.06)
	draw_rect(r, bot)

	# vertical gradient, banded so banding is visible after grading
	var bands := 64
	for i in bands:
		var t := float(i) / float(bands - 1)
		var c := top.lerp(bot, t)
		draw_rect(Rect2(0, size.y * float(i) / bands, size.x, size.y / bands + 1.0), c)

	# colour bars
	var bars := [Color.RED, Color(1, 0.5, 0), Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.MAGENTA]
	var bw := size.x / float(bars.size())
	for i in bars.size():
		draw_rect(Rect2(bw * i, size.y * 0.18, bw, size.y * 0.10), bars[i])

	# fine grid — the sharpness reference for pixelize / blur
	var step := 32.0
	var g := Color(1, 1, 1, 0.10)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), g, 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), g, 1.0)
		y += step

	# radial resolution wedge — shows pixelation/moire clearly
	var c := Vector2(size.x * 0.72, size.y * 0.62)
	for i in 12:
		var rad := 14.0 + i * 13.0
		draw_arc(c, rad, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 1.5)

	# moving boxes so temporal effects (glitch, jitter) are obvious
	for i in 5:
		var px := fposmod(_t * (40.0 + i * 23.0), size.x + 120.0) - 60.0
		var py := size.y * (0.32 + i * 0.09)
		draw_rect(Rect2(px, py, 90.0, 26.0), Color.from_hsv(fmod(i * 0.19 + _t * 0.2, 1.0), 0.75, 1.0))

	# moving scanline bar
	var bar_y := fposmod(_t * 90.0, size.y)
	draw_rect(Rect2(0, bar_y, size.x, 3.0), Color(1, 1, 1, 0.35))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 54), "XPL // GODOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 0.92))
	draw_string(font, Vector2(24, 82), "the quick brown fox jumps over 0123456789", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))


# ---------------------------------------------------------------------------
# Effect chain
# ---------------------------------------------------------------------------

func _build_chain() -> void:
	for fx in EFFECTS:
		var mat := ShaderMaterial.new()
		mat.shader = load(fx["shader"])

		var rect := ColorRect.new()
		rect.material = mat
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.visible = fx["on"]
		add_child(rect)

		var entry := {"rect": rect, "mat": mat, "fx": fx, "on": fx["on"]}
		_layers.append(entry)

		for p in fx["params"]:
			if p.has("default"):
				mat.set_shader_parameter(p["name"], p["default"])


func _set_layer_enabled(i: int, on: bool) -> void:
	var l := _layers[i]
	l["on"] = on
	l["rect"].visible = on


func _set_param(i: int, name: String, value: Variant) -> void:
	_layers[i]["mat"].set_shader_parameter(name, value)


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(330, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "XPL effects stack"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "Layers apply top-to-bottom. Tab hides UI, F12 screenshot."
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	vb.add_child(hint)

	vb.add_child(HSeparator.new())

	for i in _layers.size():
		_build_effect_row(vb, i)

	if _hide_ui:
		panel.visible = false


func _build_effect_row(parent: VBoxContainer, i: int) -> void:
	var fx: Dictionary = _layers[i]["fx"]

	var cb := CheckBox.new()
	cb.text = fx["label"]
	cb.button_pressed = _layers[i]["on"]
	cb.toggled.connect(func(on: bool) -> void: _set_layer_enabled(i, on))
	parent.add_child(cb)

	# Indent params under the checkbox so the stack reads as a list.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	parent.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	for p in fx["params"]:
		if p.has("options"):
			var opt := OptionButton.new()
			for o in p["options"]:
				opt.add_item(o)
			opt.select(0)
			opt.item_selected.connect(func(idx: int) -> void: _set_param(i, p["name"], idx))
			vb.add_child(opt)
		else:
			var row := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = p["label"]
			lbl.custom_minimum_size = Vector2(96, 0)
			lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(lbl)

			var sl := HSlider.new()
			sl.min_value = p["min"]
			sl.max_value = p["max"]
			sl.step = 0.001
			sl.value = p["default"]
			sl.custom_minimum_size = Vector2(150, 16)
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sl.value_changed.connect(func(v: float) -> void: _set_param(i, p["name"], v))
			row.add_child(sl)

			var val := Label.new()
			val.text = "%.2f" % p["default"]
			val.custom_minimum_size = Vector2(44, 0)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val.add_theme_font_size_override("font_size", 12)
			sl.value_changed.connect(func(v: float) -> void: val.text = "%.2f" % v)
			row.add_child(val)

			vb.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				for c in get_children():
					if c is PanelContainer:
						c.visible = not c.visible
			KEY_F12:
				var img := get_viewport().get_texture().get_image()
				img.save_png("user://xpl_screenshot.png")
				print("saved screenshot to ", ProjectSettings.globalize_path("user://xpl_screenshot.png"))