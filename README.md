# XPL for Godot

Post-processing effects from [QianMo/X-PostProcessing-Library](https://github.com/QianMo/X-PostProcessing-Library)
(XPL), ported from Unity HLSL to **Godot 4** — no Unity, no `PostProcessing Stack v2`.

XPL is a large collection of high-quality screen-space post-processing shaders, but it is
built against Unity's HLSL and Unity-only helpers, and it is not maintained for recent
Unity versions. The effect *math* is portable, so this repository re-expresses it in
Godot's shading language and ships it as plain `.gdshader` files with no texture assets
and no add-on plumbing.

**Status: 6 of upstream's ~146 effects are ported.** See
[Ported effects](#ported-effects) and [Limitations](#limitations).

---

## Contents

- [Ported effects](#ported-effects)
- [Requirements](#requirements)
- [Running the demo](#running-the-demo)
- [Using the shaders in your own project](#using-the-shaders-in-your-own-project)
- [Shader parameters](#shader-parameters)
- [How the effect chain works](#how-the-effect-chain-works)
- [Headless rendering](#headless-rendering)
- [Adding a new effect](#adding-a-new-effect)
- [Deviations from upstream](#deviations-from-upstream)
- [Limitations](#limitations)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Ported effects

| Effect | Upstream source | What it does |
|---|---|---|
| **Glitch RGB Split** | `Effects/GlitchRGBSplitV5` | Animates an RGB channel split using a hash-based noise field. Upstream's `_NoiseTex` LUT is replaced by an in-shader hash, so no texture assets are needed. |
| **Glitch Image Block** | `Effects/GlitchImageBlockV4` | Displaces quantised blocks of the frame in varying directions and splits the RGB channels along the same offset. |
| **Pixelize Quad** | `Effects/PixelizeQuad` | Snaps UVs to a grid so the frame is drawn as large square pixels, with independent x/y cell aspect. |
| **Chromatic Aberration** | `Shaders/XPostProcessing.hlsl` → `ChromaticAberration()` | Radial colour fringing: red and blue are sampled along the vector from the pixel to the screen centre. |
| **Vignette** | `Effects/RapidVignette` (`Frag_ColorAdjust`) | Darkens the frame towards the edges. Adds a `softness` control that upstream does not have. |
| **Color Adjust** | `Effects/ColorAdjustmentContrastV3` + `ColorAdjustmentSaturation` + `ColorAdjustmentBrightness` | Contrast / saturation / brightness grading, with all 23 upstream blend modes exposed as a single dropdown. |
| **Blend operations ×23** | `Shaders/XPostProcessing.hlsl` → `BlendOperation_*` | Burn, Darken, Difference, Dodge, Divide, Exclusion, Hard Light, Hard Mix, Lighten, Linear Burn, Linear Dodge, Linear Light, Linear Light Add/Sub, Multiply, Negation, Overlay, Pin Light, Screen, Soft Light, Soft Light V2, Subtract, Vivid Light, Overwrite — dispatched through one `blend_operation(int, …)` entry point. |

---

## Requirements

- **Godot 4.7** (`project.godot` declares `config/features=PackedStringArray("4.7", "GL Compatibility")`).
  Developed and verified against **Godot 4.7.2.stable**.
- The project uses the **Compatibility (OpenGL 3) renderer**, set in `project.godot` via
  `renderer/rendering_method="gl_compatibility"`. No Forward+/Mobile features are used, so
  it also runs on software GL stacks.
- No add-ons, no GDExtension, no imported textures — the whole project is text.

---

## Running the demo

### From the Godot editor

1. Open the Godot Project Manager.
2. Choose **Import**, select `project.godot` in this repository and confirm.
3. Press **F5** (Run Project) or the ▶ button. The main scene is `scenes/main.tscn`, which
   is already set as `run/main_scene` in `project.godot`.

### From the command line

```bash
godot --path /path/to/xpl-godot
```

### What you see

The demo draws a synthetic test pattern (banded gradient, colour bars, a fine grid, a
radial resolution wedge and moving boxes/scanline) and stacks the effect layers over it.
A panel in the top-left lets you toggle each layer and drag its parameters; the layers
apply top-to-bottom, so a pixelize layer *below* a blur layer gives blurred pixels.

| Key | Action |
|---|---|
| `Tab` | Show / hide the control panel |
| `F12` | Save a screenshot to `user://xpl_screenshot.png` |

---

## Using the shaders in your own project

Every effect is a standalone `canvas_item` shader that samples `hint_screen_texture`, so
no renderer-specific setup is needed.

### 1. Copy the shader files

Copy the `shaders/` directory into your project, e.g. to `res://shaders/`:

```
your_project/
├── shaders/
│   ├── xpl_common.gdshaderinc
│   ├── chromatic_aberration.gdshader
│   ├── color_adjust.gdshader
│   ├── glitch_image_block.gdshader
│   ├── glitch_rgb_split.gdshader
│   ├── pixelize_quad.gdshader
│   └── vignette.gdshader
```

If you put them somewhere else, update the include line in each `.gdshader`:

```glsl
#include "res://shaders/xpl_common.gdshaderinc"
```

The include is **mandatory**: `xpl_common.gdshaderinc` holds the shared hash/noise
helpers, the luminance functions, the chromatic-aberration helper and all 23 blend
operations. `color_adjust.gdshader`, `glitch_rgb_split.gdshader` and
`chromatic_aberration.gdshader` will not compile without it.

### 2. Apply the shader to a full-screen node

Add a `ColorRect` as a child of your scene, anchor it to the full rect, and assign a
`ShaderMaterial` that uses one of the `.gdshader` files.

In the editor: *Add a Control node → ColorRect*, set **Layout → Anchors → Full Rect**,
then on the ColorRect set **Material → Shader** to `res://shaders/vignette.gdshader`.

In code:

```gdscript
var rect := ColorRect.new()
rect.set_anchors_preset(Control.PRESET_FULL_RECT)
rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

var mat := ShaderMaterial.new()
mat.shader = load("res://shaders/vignette.gdshader")
mat.set_shader_parameter("amount", 0.8)
mat.set_shader_parameter("softness", 0.5)
rect.material = mat
add_child(rect)
```

### 3. Order matters

`hint_screen_texture` reads the framebuffer **as of that node's own draw**. To post-process
the scene, the `ColorRect` must be drawn *after* the content it should affect — put it
last in the tree (or above the content in the CanvasItem tree order). Two effects can be
stacked by adding two `ColorRect`s; the one later in the tree sees the output of the
earlier one.

### 4. Drive the parameters

```gdscript
mat.set_shader_parameter("amount", 12.0)   # chromatic aberration
mat.set_shader_parameter("blend_mode", 15) # overlay
mat.set_shader_parameter("blend_opacity", 0.35)
mat.set_shader_parameter("blend_color", Color(1.0, 0.2, 0.6, 1.0))
```

`screen_tex` is declared as a `sampler2D` with `hint_screen_texture`; Godot fills it with
the screen texture automatically — you never set it yourself.

---

## Shader parameters

Every shader declares `screen_tex` (`sampler2D`, `hint_screen_texture`). The rest:

### `chromatic_aberration.gdshader`

| Uniform | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `amount` | float | 0.0 – 40.0 | 4.0 | Strength of the radial channel separation, in pixels. |

### `color_adjust.gdshader`

| Uniform | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `contrast` | float | -1.0 – 2.0 | 0.35 | Upstream V3 contrast: `out = (in - 0.5) * (1 - contrast) + 0.5`. |
| `saturation` | float | 0.0 – 3.0 | 1.3 | Multiplier on the luma-weighted colour (`luminance_v1` weighting, as upstream). |
| `brightness` | float | -1.0 – 1.0 | 0.0 | Additive brightness offset. |
| `blend_mode` | int | 0 – 22 | 0 | Index into the 23 upstream `BlendOperation_*` functions (see the table above; 0 = Burn). |
| `blend_opacity` | float | 0.0 – 1.0 | 0.0 | Crossfade into the blend result. 0 passes the grade through untouched. |
| `blend_color` | vec4 (`source_color`) | — | `(1.0, 0.2, 0.6, 1.0)` | The colour that is blended in. |

### `glitch_image_block.gdshader`

| Uniform | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `speed` | float | 0.0 – 30.0 | 8.0 | Rate at which the per-block noise is re-seeded. |
| `block_size` | float | 1.0 – 80.0 | 18.0 | Grid resolution of the quantised blocks. |
| `rgb_split` | float | 0.0 – 0.5 | 0.08 | Extra RGB channel offset applied alongside the block displacement. |

### `glitch_rgb_split.gdshader`

| Uniform | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `amplitude` | float | 0.0 – 0.2 | 0.02 | Size of the animated RGB split. |
| `speed` | float | 0.0 – 10.0 | 1.0 | Speed of the noise animation. |

### `pixelize_quad.gdshader`

| Uniform | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `pixel_size` | float | 1.0 – 80.0 | 14.0 | Size of one pixelised cell, in UV units. |
| `pixel_ratio` | float | 0.25 – 4.0 | 1.0 | Aspect correction applied to the y axis. |

### `vignette.gdshader`

| Uniform | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `amount` | float | 0.0 – 2.0 | 0.6 | Vignette intensity. |
| `softness` | float | 0.01 – 1.5 | 0.45 | Falloff exponent. Not present upstream — it was added here so the control feels linear instead of `1/d²`. |
| `vignette_color` | vec4 (`source_color`) | — | `(0, 0, 0, 1)` | Colour mixed in at the edges when `tint` is enabled. |
| `tint` | bool | — | `true` | `true` mixes toward `vignette_color`; `false` multiplies the frame by the falloff (upstream `Frag`). |

---

## How the effect chain works

The harness mirrors how an XPL post-processing profile works: each effect is a
fullscreen `ColorRect` running one `canvas_item` shader that samples `hint_screen_texture`.

```
main.gd                          EFFECT registry + UI + test pattern
shaders/xpl_common.gdshaderinc   shared helpers, incl. all 23 BlendOperation_* functions
shaders/*.gdshader               one per effect
```

Because every `ColorRect` reads the buffer as of its own draw, they compose in tree order.

---

## Headless rendering

Effects can be rendered without a human at the screen, which is useful for visual
regression checks and for verifying that shaders compile:

```bash
godot --path /path/to/xpl-godot -- --shot out.png --noui --only pixelize
```

Everything after `--` is passed to the project (`OS.get_cmdline_user_args()`):

| Flag | Effect |
|---|---|
| `--shot <path>` | Render 10 frames, save a PNG to `<path>` and quit. |
| `--noui` | Hide the control panel. |
| `--only <id>` | Enable exactly one layer. Ids: `color_adjust`, `chromatic`, `pixelize`, `vignette`, `image_block`, `rgb_split`. |
| `--all` | Enable every layer. |

To check that all shaders compile without a GPU:

```bash
godot --path /path/to/xpl-godot --headless --quit
```

Any shader error is printed as `SHADER ERROR: …` / `ERROR: Shader compilation failed.`

---

## Adding a new effect

1. Drop a new `.gdshader` into `shaders/`, including
   `#include "res://shaders/xpl_common.gdshaderinc"`.
2. Add one row to the `EFFECTS` array in `main.gd` with an `id`, `label`, `shader` path and
   the parameter list (`name`, `label`, `min`, `max`, `default`, or `options` for a
   dropdown).
3. The panel, the layer stack and the `--only` / `--all` switches pick it up automatically.

---

## Deviations from upstream

Godot's shading language is stricter than HLSL, so a few things had to change:

- **No implicit scalar→vector splat.** Upstream's `half2 block = randomNoise(...)` relies
  on HLSL splatting a `float` across `.xy`. Only `.x` was ever read, so the port keeps it a
  plain `float`.
- **`hint_range` only applies to `float`/`int`.** `vignette.tint` is a bare `bool`.
- **Noise LUT replaced by a hash.** `GlitchRGBSplitV5` samples a `_NoiseTex`; the port
  hashes directly in `noise4()`, so the shaders need no texture assets at all.
- **Unity-only code dropped:** `unity_CameraProjection`, `unity_OrthoParams`,
  `UNITY_BRANCH`, stereo handling, `DownsampleBox4Tap`, `TransformTriangleVertexToUV`,
  `DecodeViewNormalStereo`.
- **Vignette aspect.** Upstream measures squared distance in raw UV space, so its falloff
  is a circle that does not match the screen. Kept as-is for fidelity.
- **`softness` on the vignette** and the **single `blend_operation()` dispatch** are
  additions, not ports.

---

## Limitations

- **Only 6 of ~146 upstream effects are ported.** Blur and depth-of-field need
  multi-pass ping-pong rendering, which `hint_screen_texture` cannot do — porting them
  requires a `CompositorEffect` or a `BackBufferCopy` viewport. Edge detection and the
  remaining glitch/pixelate variants are not ported either.
- **Single-pass only.** Every effect here is one fullscreen pass over the previous
  framebuffer. There is no history buffer, so effects that need temporal feedback are not
  supported.
- **Compatibility renderer.** The project is configured for `gl_compatibility`. The
  shaders themselves are renderer-agnostic, but the demo has not been tested on
  Forward+/Mobile.
- **Screen-space only.** There is no depth/normal input, so effects that need scene
  geometry cannot be reproduced.
- **`hint_screen_texture` limits the effect stack.** Each layer reads the buffer as of
  its own draw, so effects that need to sample the *original* frame further down the
  chain will not see it.
- **Vignette falloff is circular**, not aspect-corrected — inherited from upstream and
  kept for fidelity.
- **Upstream XPL is unmaintained** for recent Unity versions, so effects that depend on
  Unity behaviour that changed may not port cleanly.

---

## License

MIT — see [`LICENSE`](LICENSE).

The port is of QianMo's X-PostProcessing-Library, which is also MIT licensed; QianMo
retains copyright in the original shaders. See
[upstream LICENSE](https://github.com/QianMo/X-PostProcessing-Library/blob/master/LICENSE).

## Acknowledgements

- **QianMo** — [X-PostProcessing-Library](https://github.com/QianMo/X-PostProcessing-Library),
  the source of every effect in this repository.
- The **Godot Engine** community, for the shading language and the `hint_screen_texture`
  workflow this port relies on.
