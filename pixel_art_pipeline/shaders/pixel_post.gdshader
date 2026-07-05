shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
// Full-screen post pass inside the low-res SubViewport (pipeline layers 3+4).
//
// Runs on a 2x2 quad forced to the near plane (see vertex()). Reading
// hint_screen_texture puts the material in the transparent pass, so it sees
// the finished opaque scene; render_priority is negative on the material so
// alpha FX (shockwave ring) still draw on top of the processed frame.
//
// Stages, in order, each independently toggleable (driven by
// PixelArtPipeline, tunable here in the material inspector):
//   1. outline  — depth silhouettes + normal creases, single-texel lines
//   2. dither   — 8x8 Bayer offset scaled to one quantisation step
//   3. quantize — round each channel to `color_levels` levels (gamma-space)

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

uniform bool outline_enabled = true;
uniform bool quantize_enabled = true;
uniform bool dither_enabled = true;

group_uniforms outline;
uniform vec4 outline_color : source_color = vec4(0.07, 0.06, 0.1, 1.0);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.85;
/// Scales the depth gap needed to count as a silhouette edge. Lower = more
/// outlines. The threshold already grows with distance and grazing angle,
/// so this stays a single intuitive knob.
uniform float depth_edge_scale : hint_range(0.1, 8.0) = 1.5;
/// Crease edge when neighbouring normals disagree by more than this
/// (1 - dot). High values keep interior surfaces clean (chunky look).
uniform float normal_edge_threshold : hint_range(0.05, 1.0) = 0.55;
group_uniforms;

group_uniforms color_crush;
/// Output levels per RGB channel ("palette size"): 6 -> 216-colour palette.
uniform int color_levels : hint_range(2, 32) = 6;
/// Bayer offset amplitude in quantisation steps (1.0 = full step).
uniform float dither_strength : hint_range(0.0, 2.0) = 0.85;
group_uniforms;

const int BAYER[64] = int[](
	 0, 32,  8, 40,  2, 34, 10, 42,
	48, 16, 56, 24, 50, 18, 58, 26,
	12, 44,  4, 36, 14, 46,  6, 38,
	60, 28, 52, 20, 62, 30, 54, 22,
	 3, 35, 11, 43,  1, 33,  9, 41,
	51, 19, 59, 27, 49, 17, 57, 25,
	15, 47,  7, 39, 13, 45,  5, 37,
	63, 31, 55, 23, 61, 29, 53, 21
);


void vertex() {
	// Force the quad to cover the whole viewport at the near plane
	// (Godot 4.3+ reversed-z convention).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}


vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}


void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;

	// -- 1. Depth + normal outline ---------------------------------------
	float raw_depth = texture(depth_tex, uv).r;
	// raw_depth == 0.0 is the sky (reversed z): never outline sky pixels.
	if (outline_enabled && raw_depth > 1e-6) {
		vec2 px = 1.0 / VIEWPORT_SIZE;
		float dc = linear_depth(uv, INV_PROJECTION_MATRIX);
		float dl = linear_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		float dr = linear_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		float du = linear_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
		float dd = linear_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);

		// The line lands on the *near* side of a depth discontinuity, i.e.
		// on the object's own silhouette — the pixel-art outline placement.
		float gap = max(max(dl, dr), max(du, dd)) - dc;

		// Threshold grows with distance and with grazing view angle, so
		// floors seen edge-on don't light up with false outlines.
		vec3 nc = view_normal(uv);
		vec4 vpos = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
		vec3 vdir = normalize(-vpos.xyz / vpos.w);
		float ndv = clamp(dot(nc, vdir), 0.0, 1.0);
		float thresh = depth_edge_scale * (0.05 + 0.03 * dc) / max(ndv, 0.25);
		float edge = step(thresh, gap);

		// Crease outlines from normal disagreement (arch reveals, box edges).
		float ndiff = 0.0;
		ndiff = max(ndiff, 1.0 - dot(nc, view_normal(uv - vec2(px.x, 0.0))));
		ndiff = max(ndiff, 1.0 - dot(nc, view_normal(uv + vec2(px.x, 0.0))));
		ndiff = max(ndiff, 1.0 - dot(nc, view_normal(uv - vec2(0.0, px.y))));
		ndiff = max(ndiff, 1.0 - dot(nc, view_normal(uv + vec2(0.0, px.y))));
		edge = max(edge, step(normal_edge_threshold, ndiff));

		col = mix(col, outline_color.rgb, edge * outline_strength);
	}

	// -- 2+3. Ordered dither, then colour quantization --------------------
	// Done on a gamma-encoded copy so the bands are spaced perceptually,
	// then returned to linear for the engine's tonemap.
	vec3 g = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));
	float levels = float(max(color_levels, 2) - 1);
	if (dither_enabled) {
		ivec2 pc = ivec2(FRAGCOORD.xy);
		float b = (float(BAYER[(pc.y % 8) * 8 + (pc.x % 8)]) + 0.5) / 64.0;
		g += (b - 0.5) * dither_strength / levels;
	}
	if (quantize_enabled) {
		g = round(g * levels) / levels;
	}
	col = pow(clamp(g, vec3(0.0), vec3(1.0)), vec3(2.2));

	ALBEDO = col;
}
