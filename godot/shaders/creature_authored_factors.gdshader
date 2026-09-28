shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// The five runtime GLBs have constant PBR factors and no texture maps.
// Reproduce those factors while retaining the exact runtime wing deformation.
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.7;
uniform float metallic = 0.0;
uniform float specular_amount = 0.5;
uniform vec4 authored_emission : source_color = vec4(0.0);
uniform float wing_flex = 0.0;
void vertex() {
    float span = smoothstep(0.15,2.2,abs(VERTEX.x));
    VERTEX.z += wing_flex * span * span;
    VERTEX.y += wing_flex * span * 0.28;
}
void fragment() {
    ALBEDO = tint.rgb;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    SPECULAR = specular_amount;
    EMISSION = authored_emission.rgb;
    if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
