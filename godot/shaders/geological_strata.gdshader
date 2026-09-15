shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D basalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex() {
    wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 blend=pow(abs(wn),vec3(4.0));
    blend/=max(dot(blend,vec3(1.0)),.001);
    vec3 tex=texture(basalt_map,wp.yz*.09).rgb*blend.x+texture(basalt_map,wp.xz*.09).rgb*blend.y+texture(basalt_map,wp.xy*.09).rgb*blend.z;
    float fault=noise(wp.xz*.028);
    float layers=noise(vec2(wp.y*.11+fault*.85,5.7))*.65+noise(vec2(wp.y*.31,wp.x*.007+wp.z*.006))*.35;
    float band=smoothstep(.42,.72,layers);
    float fracture=pow(noise(vec2(wp.x*.08+wp.z*.047,wp.y*.12)),2.0);
    vec3 charcoal=vec3(.067,.069,.085);
    vec3 oxide=vec3(.126,.098,.083);
    vec3 stone=mix(charcoal,oxide,band*.60+fault*.13);
    float cap=smoothstep(.66,.96,wn.y);
    stone=mix(stone,vec3(.21,.155,.105),cap*.43);
    ALBEDO=stone*(.72+tex*3.0)*(1.0-fracture*.36);
    ROUGHNESS=.83+texture(rough_map,wp.xz*.1).r*.13;
    SPECULAR=.18;
}
