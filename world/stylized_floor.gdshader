shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.012, 0.018, 0.04, 1.0);
uniform vec4 grid_color : source_color = vec4(0.035, 0.26, 0.31, 1.0);
uniform vec4 hot_color : source_color = vec4(0.72, 0.025, 0.33, 1.0);
uniform float grid_size = 2.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float width) {
	vec2 cell = abs(fract(p) - 0.5);
	float line = min(cell.x, cell.y);
	return 1.0 - smoothstep(width, width + 0.018, line);
}

void fragment() {
	vec2 p = world_position.xz / grid_size;
	float fine_grid = grid_line(p, 0.015);
	float block_grid = grid_line(p / 4.0, 0.009);
	float lane_a = smoothstep(0.09, 0.02, abs(fract(world_position.x * 0.055 + 0.5) - 0.5));
	float lane_b = smoothstep(0.055, 0.012, abs(fract(world_position.z * 0.071 + 0.25) - 0.5));
	float moving_signal = pow(max(0.0, sin(world_position.z * 0.42 - TIME * 1.6)), 18.0) * lane_a;
	float magenta_signal = pow(max(0.0, sin(world_position.x * 0.35 + TIME * 1.1)), 24.0) * lane_b;

	vec3 color = base_color.rgb + grid_color.rgb * fine_grid * 0.16 + grid_color.rgb * block_grid * 0.22;
	ALBEDO = color;
	METALLIC = 0.68;
	ROUGHNESS = 0.24;
	EMISSION = grid_color.rgb * (fine_grid * 0.09 + block_grid * 0.16 + moving_signal * 1.6)
		+ hot_color.rgb * magenta_signal * 1.25;
}

