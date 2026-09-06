shader_type canvas_item;

// The lantern. The maze underneath is drawn at full brightness and this layer
// takes the light away again — which is why it can be smooth: visibility is
// computed per cell on the CPU (it has to be, it is a line-of-sight test), then
// handed over as a tiny COLS x ROWS texture and sampled with bilinear filtering.
// Interpolating between cell centres on the GPU is what turns a mosaic of
// squares into a light.

// R = how lit the cell is right now. G = whether it has ever been seen.
// The second channel matters: a cell the player has explored must stay legible
// even in the dark, because the remembered map IS the game. Without a floor on
// its brightness the lantern layer buries it and the player is left with a
// pinhole and no memory to contradict.
uniform sampler2D light_map : filter_linear, repeat_disable;
uniform float memory_brightness : hint_range(0.0, 1.0) = 0.34;
uniform vec3 shadow_color = vec3(0.045, 0.035, 0.08);
uniform vec3 warm = vec3(1.0, 0.82, 0.55);
uniform float flicker = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float time_seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 sampled = texture(light_map, UV).rg;
	float vis = clamp(sampled.r * flicker, 0.0, 1.0);
	float seen = clamp(sampled.g, 0.0, 1.0);
	vis = max(vis, seen * memory_brightness);

	// Bias the curve so the falloff spends more of its range near the edge of
	// the lantern, where the eye is actually looking for the boundary.
	float dark = pow(1.0 - vis, 1.4);

	// The far corners of the screen sit under a little more shadow than the
	// light map alone would give, which keeps the frame from reading flat.
	vec2 centred = UV - vec2(0.5);
	float vignette = smoothstep(0.35, 0.95, length(centred * vec2(1.0, 0.62)) * 2.0);
	dark = clamp(dark + vignette * vignette_strength * (1.0 - vis * 0.85), 0.0, 1.0);

	// A little warmth bled into the lit area: a flame is not a white torch.
	vec3 tint = mix(shadow_color, warm, vis * 0.10);

	float grain = (hash(UV * 900.0 + vec2(time_seed)) - 0.5) * grain_strength;

	COLOR = vec4(tint, clamp(dark * 0.96 + grain * dark, 0.0, 1.0));
}
