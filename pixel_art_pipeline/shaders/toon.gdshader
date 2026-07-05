shader_type spatial;
// Stepped/toon lighting replacement for PBR (pipeline layer 5).
//
// Every material in the demo scenes is a ShaderMaterial on this shader (see
// pixel_art_pipeline/materials/). The `pixel_toon_enabled` global (declared in
// project.godot, driven by PixelArtPipeline) cross-fades the whole scene
// between stepped bands and plain smooth lambert, so the layer can be A/B'd
// live without touching any material.
//
// Point lights get the same treatment: distance falloff is folded into the
// band quantisation, so omni light pools read as concentric stepped rings —
// which the ordered-dither pass then breaks up (the castle torch stress test).

global uniform float pixel_toon_enabled;

uniform vec4 albedo_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
/// Number of lit bands between full shadow and full light.
uniform int band_count : hint_range(2, 5) = 3;
/// Width of the transition between bands (0 = hard pixel step).
uniform float band_softness : hint_range(0.0, 0.25) = 0.02;
/// View-edge rim highlight band on the lit side (0 disables).
uniform float rim_size : hint_range(0.0, 1.0) = 0.2;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
/// Self-glow for flames / pads; tinted by the albedo colour.
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;


void fragment() {
	ALBEDO = albedo_color.rgb;
	EMISSION = albedo_color.rgb * emission_energy;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}


void light() {
	// Shadowing and (for omnis) distance falloff arrive via ATTENUATION, so
	// quantising ndl bands both the terminator and the light-pool falloff.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float bands = float(band_count);
	float x = ndl * bands;
	float soft = max(band_softness * bands, 1e-4);
	float q = 0.0;
	for (int i = 1; i < band_count; i++) {
		q += smoothstep(float(i) - soft, float(i) + soft, x);
	}
	q /= max(bands - 1.0, 1.0);
	// Rim band: only on surfaces that are already lit, so it reads as an
	// edge highlight rather than an outline.
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim_band = step(1.0 - rim_size, rim) * rim_strength * step(0.001, q);
	float lit = mix(ndl, q + rim_band, pixel_toon_enabled);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lit / PI;
}
