shader_type canvas_item;

// Draws the edge of what you can see. Not decoration: in this prototype the
// screen border is where the rules change, so it is worth being able to feel it.
// Cheap enough to leave on - no screen texture, one length() per pixel.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float inner : hint_range(0.0, 1.5) = 0.55;
uniform float outer : hint_range(0.0, 2.0) = 1.10;
uniform vec2 aspect = vec2(1.0, 0.5625);

void fragment() {
	vec2 d = (UV - vec2(0.5)) * aspect / aspect.x;
	float falloff = smoothstep(inner, outer, length(d) * 2.0);
	COLOR = vec4(0.02, 0.015, 0.05, falloff * strength);
}
