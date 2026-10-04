shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 core_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform vec4 response_color : source_color = vec4(0.12, 0.94, 0.84, 1.0);
uniform float front_height = -40.0;
uniform float front_strength = 0.0;
uniform float linked = 0.0;
uniform float responding = 0.0;
varying float branch_height;
void vertex() {
    branch_height = VERTEX.y;
}
void fragment() {
    float arrival = exp(-pow((branch_height - front_height) / 28.0, 2.0));
    vec3 signal_color = mix(core_color.rgb, response_color.rgb, responding);
    // Keep the idle veins below display white, so the travelling front has contrast.
    ALBEDO = core_color.rgb * 0.04;
    EMISSION = core_color.rgb * 0.12 + response_color.rgb * linked * 0.30
        + signal_color * arrival * front_strength * 0.92;
}

