shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D basalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dust_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 wetland_center = vec2(-32.0,-342.0);
uniform float water_level = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 uv=world_pos.xz*.11;
 float route=18.0*sin((150.0-world_pos.z)*.012)+4.0*sin((150.0-world_pos.z)*.033);
 float shoulder=smoothstep(4.4,12.0,abs(world_pos.x-route));
 float macro=n(world_pos.xz*.042), flow=n(world_pos.xz*vec2(.045,.15)+vec2(macro*2.0));
 float grain=texture(rough_map,uv*.25).r;
 float slope=1.0-smoothstep(.72,.96,world_normal.y);
 float dust=clamp(.95-shoulder*.67-slope*.5+(macro-.5)*.7,.06,1.0);
 vec3 rock=texture(basalt_map,uv).rgb;
 vec3 sand=texture(dust_map,uv*.64+vec2(.21)).rgb;
 vec3 base=mix(rock*.82,sand*.79,dust)*(.82+macro*.28);
 float z=world_pos.z+sin(world_pos.x*.055)*11.0+(macro-.5)*24.0;
 float ember=1.0-smoothstep(-38.0,20.0,z);
 float marsh=1.0-smoothstep(-201.0,-142.0,z);
 float decay=1.0-smoothstep(-390.0,-319.0,z);
 // A watershed crosses a cartographic zone boundary: the study pool and its
 // surrounding root colonies stay damp green-brown into the Pale transition.
 vec2 basin_delta=world_pos.xz-wetland_center;
 float basin_distance=min(length(basin_delta/vec2(6.2,6.0)),min(length((basin_delta-vec2(-15.0,2.0))/vec2(22.0,14.0)),length((basin_delta-vec2(-28.0,9.0))/vec2(12.0,12.0))));
 float pool_habitat=1.0-smoothstep(1.0,2.4,basin_distance);
 decay*=1.0-pool_habitat;
 marsh=max(marsh,pool_habitat);
 float luminance=dot(base,vec3(.2126,.7152,.0722));
 float frost_mask=smoothstep(.37,.70,flow)*(.22+.64*shoulder)*(1.0-slope*.85);
 frost_mask*=.45+.55*smoothstep(-.35,.65,world_normal.x);
 vec3 neutral=mix(base,vec3(luminance),.43);
 // Project exposed stone onto its face, not only XZ: steep banks otherwise
 // stretch a few texels over the whole cliff and lose their geological scale.
 vec3 axes=pow(abs(world_normal),vec3(4.0));axes/=max(dot(axes,vec3(1.0)),.001);
 vec3 fractured=texture(rock_detail,world_pos.zy*.28).rgb*axes.x
               +texture(rock_detail,world_pos.xz*.28).rgb*axes.y
               +texture(rock_detail,world_pos.xy*.28).rgb*axes.z;
 neutral=mix(neutral,fractured*.64,clamp(shoulder*.20+slope*.72,0.0,.90));
 vec3 frost=mix(neutral*vec3(.86,.99,1.03),vec3(.24,.31,.32)*(grain*.25+.78),frost_mask*.58);
 // Exposed bedding belongs to the tilted shelves; frost collects on sheltered tops.
 float bedding=smoothstep(.42,.70,n(vec2(world_pos.y*.16+world_pos.x*.025,world_pos.z*.037)));
 frost=mix(frost,fractured*vec3(.53,.62,.65)*(.80+bedding*.35),slope*.48);
 vec3 hot=mix(neutral*vec3(.99,.87,.75),vec3(.18,.10,.065),smoothstep(.4,.77,flow)*shoulder*.44);
 float mineral=smoothstep(.61,.75,flow)*shoulder;
 hot=mix(hot,vec3(.27,.22,.135),mineral*.43);
 float fault_axis=abs(world_pos.x+49.0-(world_pos.z+80.0)*.24);
 float fault_deposit=exp(-pow(fault_axis/22.0,2.0))*shoulder;
 hot=mix(hot,vec3(.115,.09,.071)*( .85+grain*.3),fault_deposit*slope*.5);
 vec3 wetsoil=mix(neutral,neutral*vec3(.56,.80,.65),.64);
 vec3 wetgrain=texture(wet_detail,uv*2.6).rgb;
 wetsoil*=.73+wetgrain*.75;
 vec3 oldsoil=mix(neutral,neutral*vec3(.95,.84,.92),.60);
 float mycelium=smoothstep(.65,.8,macro)*shoulder;
 oldsoil=mix(oldsoil,vec3(.30,.28,.30),mycelium*.39);
 oldsoil=mix(oldsoil,fractured*vec3(.61,.55,.50)*(.8+bedding*.3),slope*.68);
 ALBEDO=mix(mix(mix(frost,hot,ember),wetsoil,marsh),oldsoil,decay);
 float shore_distance=basin_distance;
 float water_depth=water_level-world_pos.y;
 float wet_rim=(1.0-smoothstep(1.0,1.45,shore_distance))*(1.0-smoothstep(.0,.85,-water_depth));
 float silt=(1.0-smoothstep(1.1,1.7,shore_distance))*(1.0-smoothstep(.30,1.6,-water_depth));
 vec3 sediment=wetgrain*vec3(.48,.42,.31);
 ALBEDO=mix(ALBEDO,sediment,silt*.66);
 float moisture=max(wet_rim,smoothstep(.55,.83,flow)*marsh*(1.0-decay)*shoulder*.65);
 ALBEDO=mix(ALBEDO,vec3(.145,.165,.123)*(.87+grain*.24),wet_rim*.35);
 ALBEDO*=mix(1.0,.84,moisture);
 ROUGHNESS=mix(clamp(.70+texture(rough_map,uv).r*.27,.7,.98),.30,moisture*.88);
 SPECULAR=.32;
 NORMAL_MAP=mix(texture(normal_map,uv).rgb,texture(wet_normal,uv*2.6).rgb,marsh*(1.0-decay)*.65);
 NORMAL_MAP_DEPTH=mix(.52,.13,dust)*(1.0-moisture*.55);
}

