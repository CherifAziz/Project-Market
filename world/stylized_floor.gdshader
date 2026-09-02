shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 stone_color : source_color = vec4(0.61, 0.57, 0.50, 1.0);
uniform vec4 joint_color : source_color = vec4(0.38, 0.36, 0.33, 1.0);
uniform float slab_size = 2.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

void fragment() {
	vec2 slab = world_position.xz / slab_size;
	vec2 edge_distance = abs(fract(slab) - 0.5);
	float joint = 1.0 - smoothstep(0.476, 0.49, max(edge_distance.x, edge_distance.y));
	float variation = hash21(floor(slab)) * 0.07 - 0.035;
	float fine_grain = hash21(floor(world_position.xz * 3.0)) * 0.018;
	vec3 color = stone_color.rgb + variation + fine_grain;
	ALBEDO = mix(color, joint_color.rgb, joint * 0.24);
	METALLIC = 0.0;
	ROUGHNESS = 0.82 + variation * 0.35;
}
