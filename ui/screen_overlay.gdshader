shader_type canvas_item;

void fragment() {
	float edge = smoothstep(0.52, 0.88, distance(UV, vec2(0.5)));
	vec3 warm_shadow = vec3(0.075, 0.065, 0.055);
	COLOR = vec4(warm_shadow, edge * 0.1);
}
