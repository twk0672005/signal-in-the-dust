shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// World code owns this clock so pause and reset freeze the pool deterministically.
uniform float world_time = 0.0;
uniform float response : hint_range(0.0, 1.0) = 0.0;
uniform float alarm : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float slow_ripple = sin(radius * 17.0 - world_time * (0.58 + response * 0.22));
	float crossing_ripple = sin((p.x * 7.0 + p.y * 5.0) + world_time * 0.36);
	float living = (slow_ripple * 0.5 + crossing_ripple * 0.5) * response;
	vec3 quiet_color = vec3(0.075, 0.16, 0.15);
	vec3 living_color = vec3(0.12, 0.285, 0.245) + living * vec3(0.012, 0.025, 0.02);
	vec3 alarm_color = vec3(0.25, 0.18, 0.105);
	ALBEDO = mix(mix(quiet_color, living_color, response), alarm_color, alarm * 0.62);
	ROUGHNESS = mix(0.46, 0.32, response);
	SPECULAR = 0.34;
	EMISSION = vec3(0.035, 0.10, 0.085) * response * (0.22 + 0.08 * slow_ripple);
}
