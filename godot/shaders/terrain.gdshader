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
    float route = 18.0*sin((150.0-world_pos.z)*0.012) + 4.0*sin((150.0-world_pos.z)*0.033);
    float banks = smoothstep(4.0,18.0,abs(world_pos.x-route));
    float grain = texture(rough_map,uv*0.127).r;
    float dunes = sin(world_pos.z*0.22+sin(world_pos.x*0.07)*2.0)*0.03;
    float dust = clamp(0.9-banks*0.87 + (grain-.8)*2.0+dunes,0.02,1.0);
    vec3 rock = texture(basalt_map, uv).rgb;
    vec3 sand = texture(dust_map, uv*0.64+vec2(.21)).rgb;
    sand=mix(sand,vec3(dot(sand,vec3(.3,.59,.11))),.15);
    vec3 base = mix(rock*.67, sand*.79, dust) * (0.82 + grain*.25);
    // Soft, irregular ecotones rather than straight painted region boundaries.
    float z = world_pos.z + sin(world_pos.x*.055)*6.0 + (grain-.5)*8.0;
    float e = 1.0-smoothstep(-30.0,10.0,z);
    float m = 1.0-smoothstep(-190.0,-150.0,z);
    float d = 1.0-smoothstep(-370.0,-330.0,z);
    vec3 neutral = vec3(dot(base,vec3(.2126,.7152,.0722)));
    vec3 frost = mix(base,neutral*.92+vec3(.025,.04,.055),.65);
    vec3 ember = base*vec3(.96,.78,.68);
    vec3 marsh = mix(base,neutral*vec3(.54,.72,.79),.65);
    vec3 decay = mix(base,neutral*vec3(.85,.78,.89),.78);
    ALBEDO = mix(mix(mix(frost,ember,e),marsh,m),decay,d);
    float moisture=smoothstep(.36,.72,grain)*m*(1.0-d);
    ALBEDO*=mix(1.0,.70,moisture);
    ROUGHNESS = mix(texture(rough_map,uv).r,.26,moisture);
    SPECULAR = .3;
    NORMAL_MAP = texture(normal_map,uv).rgb;
    NORMAL_MAP_DEPTH = mix(0.75,0.19,dust);
}
