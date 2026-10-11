# XPL for Godot

Post-processing effects ported from [QianMo/X-PostProcessing-Library](https://github.com/QianMo/X-PostProcessing-Library)
(XPL) to **Godot 4**, without Unity.

XPL is a large, high-quality collection of post-processing shaders — but it's built
against Unity's HLSL + `PostProcessing Stack v2`, and it isn't maintained for recent
Unity versions. The effect *math* is portable, so this repo re-expresses it in Godot's
shading language.

## Running

```bash
godot --path ~/Projects/xpl-godot
```

Layers stack top-to-bottom. `Tab` hides the UI, `F12` saves a screenshot.

## Architecture

The harness mirrors how an XPL post-processing profile works. Each effect is a
fullscreen `ColorRect` running a `canvas_item` shader that samples `hint_screen_texture`.
Because every ColorRect reads the buffer as of its own draw, they compose in tree order —
put a pixelize layer below a blur layer and you get blurred pixels.

```
main.gd  ── EFFECT registry + UI + test pattern
shaders/xpl_common.gdshaderinc     shared helpers, incl. all 23 BlendOperation_* functions
shaders/*.gdshader                 one per effect
```

Adding an effect = drop in a `.gdshader` + one row in `EFFECTS` in `main.gd`.

## Ported so far

| Effect | Upstream source | Notes |
|---|---|---|
| Glitch RGB Split | `GlitchRGBSplitV5` | noise LUT replaced with `noise4()` hash — no texture assets needed |
| Glitch Image Block | `GlitchImageBlockV4` | |
| Pixelize Quad | `PixelizeQuad` | |
| Chromatic Aberration | `XPostProcessing.hlsl : ChromaticAberration()` | |
| Vignette | `RapidVignette` (color-adjust pass) | added a `softness` control upstream lacks |
| Color Adjust | `ColorAdjustmentContrastV3` + Saturation + Brightness | plus all 23 blend modes as a dropdown |
| Blend ops ×23 | `XPostProcessing.hlsl : BlendOperation_*` | exposed via one `blend_operation(int, ...)` dispatch |

That's 6 of upstream's 146 effects. The remaining categories — blur (needs multi-pass
ping-pong, so `hint_screen_texture` won't do it; use `CompositorEffect` or a
`BackBufferCopy` viewport), edge detection, and the other glitch/pixelate variants — are
not ported yet.

## Verification

Effects can be rendered headlessly for inspection:

```bash
godot --path ~/Projects/xpl-godot -- --shot out.png --noui --only pixelize
```

`--only <id>` isolates one layer, `--all` enables everything, `--noui` drops the panel.

## Deviations from upstream

Godot's shading language is stricter than HLSL, so a few things had to change:

- **No implicit scalar→vector splat.** Upstream's `half2 block = randomNoise(...)`
  relies on HLSL splatting a `float` across `.xy`. Only `.x` was ever read, so the port
  keeps it a plain `float`.
- **`hint_range` only applies to `float`/`int`.** `vignette.tint` is a bare `bool`.
- **Unity-only code dropped:** `unity_CameraProjection`, `unity_OrthoParams`,
  `UNITY_BRANCH`, stereo handling, `DownsampleBox4Tap`, `TransformTriangleVertexToUV`,
  `DecodeViewNormalStereo`.
- **Vignette aspect.** Upstream measures squared distance in raw UV space, so its falloff
  is a circle that doesn't match the screen. Kept as-is for fidelity.

## Licence

MIT, matching upstream. QianMo's shaders are copyright QianMo — see `LICENSE` in the
upstream repo.