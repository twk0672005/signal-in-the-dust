shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec4 tint : source_color = vec4(.3,.35,.34,1.0);
uniform float roughness = .82;
uniform float shell = 0.0;
uniform float membrane = 0.0;
uniform float glow = 0.0;
uniform float response = 1.0;
uniform float shell_uv = 0.0;
uniform float wing_flex = 0.0;
uniform float specular_amount = 0.35;
uniform sampler2D structure_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool structure_enabled = false;
uniform bool dermal_projection = false;
uniform float normal_strength = 0.55;
uniform float surface_age = 0.35;
varying vec3 local_p;
void vertex() {
    local_p = VERTEX;
    float span = smoothstep(0.15,2.2,abs(VERTEX.x));
    VERTEX.z += wing_flex * span * span;
    VERTEX.y += wing_flex * span * 0.28;
}
void fragment() {
    ALBEDO = tint.rgb;
    ROUGHNESS = roughness;
    if (structure_enabled) {
        // Authored linear data. No procedural noise, screen derivatives,
        // transparency or additional pass. Mipmaps provide distance filtering.
        vec2 coord = dermal_projection ? local_p.zy * 0.7 : clamp(UV,vec2(0.001),vec2(0.999));
        vec4 detail = texture(structure_map,coord);
        ALBEDO *= mix(0.48,1.21,detail.r);
        vec3 worn = tint.rgb * vec3(1.26,1.16,0.92);
        float exposure = .5+.5*sin(local_p.x*2.7+local_p.z*1.9+surface_age*4.0)*cos(local_p.y*3.1);
        ALBEDO = mix(ALBEDO,worn,detail.b*(.24+surface_age*.42));
        ALBEDO *= 1.0-shell*surface_age*.10*(1.0-exposure);
        ROUGHNESS = clamp(roughness+(detail.g-0.6)*0.40,0.24,0.98);
        // Light-dependent thin tissue response; thick veins transmit less.
        BACKLIGHT = tint.rgb * membrane * (1.0-detail.a) * 0.22;
        if (!dermal_projection) {
            NORMAL_MAP = texture(surface_normal,coord).rgb;
            NORMAL_MAP_DEPTH = normal_strength;
        }
    }
    METALLIC = 0.0;
    SPECULAR = specular_amount;
    EMISSION = tint.rgb * glow * response;
    if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
