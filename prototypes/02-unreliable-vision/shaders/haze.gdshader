shader_type canvas_item;

// Full-screen warp + chromatic aberration, scaled by Perception.level.
// Three texture samples, cheap enough for software rendering.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float wave_amount = 0.007;
uniform float wave_speed = 1.0;
uniform float aberration = 0.004;

void fragment() {
	float t = TIME * wave_speed;
	vec2 uv = SCREEN_UV + vec2(
		sin(SCREEN_UV.y * 14.0 + t * 1.3),
		sin(SCREEN_UV.x * 11.0 + t * 1.7)
	) * wave_amount * intensity;

	float ab = aberration * intensity;
	COLOR = vec4(
		texture(screen_tex, uv + vec2(ab, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(ab, 0.0)).b,
		1.0
	);
}
