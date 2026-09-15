shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D basalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dust_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 uv = world_pos.xz * 0.11;
    float route = 14.0*sin((100.0-world_pos.z)*0.02);
    float banks = smoothstep(4.0,18.0,abs(world_pos.x-route));
    float grain = texture(rough_map,uv*0.127).r;
    float dunes = sin(world_pos.z*0.22+sin(world_pos.x*0.07)*2.0)*0.03;
    float dust = clamp(0.9-banks*0.87 + (grain-.8)*2.0+dunes,0.02,1.0);
    vec3 rock = texture(basalt_map, uv).rgb;
    vec3 sand = texture(dust_map, uv*0.64+vec2(.21)).rgb;
    sand=mix(sand,vec3(dot(sand,vec3(.3,.59,.11))),.15);
    ALBEDO = mix(rock*.67, sand*.79, dust) * (0.82 + grain*.25);
    ROUGHNESS = texture(rough_map,uv).r;
    SPECULAR = 0.2;
    NORMAL_MAP = texture(normal_map,uv).rgb;
    NORMAL_MAP_DEPTH = mix(0.75,0.19,dust);
}
