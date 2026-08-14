shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.34, 0.86, distance(uv, vec2(0.5)));
	float scan = sin(uv.y * 900.0) * 0.5 + 0.5;
	vec3 tint = mix(vec3(0.0), vec3(0.025, 0.08, 0.13), scan * 0.018);
	COLOR = vec4(tint, edge * 0.34 + scan * 0.009);
}

