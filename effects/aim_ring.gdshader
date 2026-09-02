shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 ring_color : source_color = vec4(0.32, 0.30, 0.23, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.58;
uniform float pulse_speed = 3.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.75;

void fragment() {
	float radius = length(UV - vec2(0.5));
	float ring = smoothstep(0.46, 0.41, radius) * smoothstep(0.32, 0.37, radius);
	float dot_core = smoothstep(0.075, 0.015, radius) * 0.7;
	float pulse = 0.86 + 0.14 * sin(TIME * pulse_speed);
	ALBEDO = ring_color.rgb;
	EMISSION = ring_color.rgb * (ring * 1.15 + dot_core) * pulse * intensity;
	ALPHA = (ring + dot_core) * alpha;
}
