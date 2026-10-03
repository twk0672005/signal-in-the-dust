shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D basalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dust_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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
 float shoulder=smoothstep(1.8,4.4,abs(world_pos.x-route)+(n(world_pos.xz*.13)-.5)*1.2);
 float macro=n(world_pos.xz*.042), flow=n(world_pos.xz*vec2(.045,.15)+vec2(macro*2.0));
 float grain=texture(rough_map,uv*.25).r;
 float slope=1.0-smoothstep(.72,.96,world_normal.y);
 float dust=clamp(.95-shoulder*.67-slope*.5+(macro-.5)*.7,.06,1.0);
 vec3 rock=texture(basalt_map,uv).rgb;
 vec3 sand=texture(dust_map,uv*.64+vec2(.21)).rgb;
 // Metre-scale scanned sediment interrupts the broad procedural colour wash.
 vec2 gravel_uv=world_pos.xz*.72;
 vec4 gravel=texture(wet_detail,gravel_uv);
 vec3 fine_stone=texture(rock_detail,world_pos.xz*.83).rgb;
 vec3 sediment_base=mix(gravel.rgb,fine_stone,smoothstep(.42,.66,flow)*.38);
 sediment_base=mix(sediment_base,vec3(dot(sediment_base,vec3(.2126,.7152,.0722))),.78)*vec3(1.04,.96,.90);
 vec3 base=mix(mix(rock*.82,sand*.79,dust),sediment_base*.78,.48)*(.68+macro*.50);
 float z=world_pos.z+sin(world_pos.x*.055)*11.0+(macro-.5)*24.0;
 float ember=1.0-smoothstep(-38.0,20.0,z);
 float marsh=1.0-smoothstep(-201.0,-142.0,z);
 float decay=1.0-smoothstep(-390.0,-319.0,z);
 // A watershed crosses a cartographic zone boundary: the study pool and its
 // surrounding root colonies stay damp green-brown into the Pale transition.
 vec2 basin_delta=world_pos.xz-wetland_center;
 float basin_distance=min(length(basin_delta/vec2(6.2,6.0)),min(length((basin_delta-vec2(-15.0,2.0))/vec2(22.0,14.0)),length((basin_delta-vec2(-28.0,9.0))/vec2(12.0,12.0))));
 float pool_habitat=1.0-smoothstep(1.0,2.4,basin_distance);
 basin_distance=min(basin_distance,min(length((basin_delta-vec2(-24.0,23.0))/vec2(29.0,30.0)),min(length((basin_delta-vec2(-49.0,31.0))/vec2(22.0,20.0)),length((basin_delta-vec2(-64.0,63.0))/vec2(18.0,38.0)))));
 pool_habitat=1.0-smoothstep(1.0,2.0,basin_distance);
 decay*=1.0-pool_habitat;
 marsh=max(marsh,pool_habitat);
 float luminance=dot(base,vec3(.2126,.7152,.0722));
 float frost_mask=smoothstep(.37,.70,flow)*(.22+.64*shoulder)*(1.0-slope*.85);
 frost_mask*=.45+.55*smoothstep(-.35,.65,world_normal.x);
 vec3 neutral=mix(base,vec3(luminance),.43);
 // Project exposed stone onto its face, not only XZ: steep banks otherwise
 // stretch a few texels over the whole cliff and lose their geological scale.
 vec3 axes=pow(abs(world_normal),vec3(4.0));axes/=max(dot(axes,vec3(1.0)),.001);
 // Scan orientation changes over broad fractured deposits, rather than drawing
 // one periodic horizontal grid across an entire wall.
 vec2 face_offset=vec2(macro*.63,flow*.41);
 vec3 fractured=texture(rock_detail,world_pos.zy*.23+face_offset).rgb*axes.x
               +texture(rock_detail,world_pos.xz*.23-face_offset).rgb*axes.y
               +texture(rock_detail,world_pos.xy*.23+face_offset.yx).rgb*axes.z;
 fractured=mix(fractured,vec3(dot(fractured,vec3(.2126,.7152,.0722))),.68);
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
 vec3 wetsoil=mix(neutral,neutral*vec3(.67,.73,.56),.74);
 vec3 wetgrain=texture(wet_detail,uv*2.6).rgb;
 wetsoil*=.78+wetgrain*.52;
 wetsoil=mix(wetsoil,vec3(.115,.135,.092)*(.78+grain*.35),smoothstep(.63,.82,flow)*shoulder*.26);
 vec3 oldsoil=mix(neutral,neutral*vec3(.95,.84,.92),.60);
 float mycelium=smoothstep(.65,.8,macro)*shoulder;
 oldsoil=mix(oldsoil,vec3(.30,.28,.30),mycelium*.39);
 oldsoil=mix(oldsoil,fractured*vec3(.61,.55,.50)*(.8+bedding*.3),slope*.68);
 ALBEDO=mix(mix(mix(frost,hot,ember),wetsoil,marsh),oldsoil,decay);
 // The signal basin has steep exposed faces around the endpoint.  Keep those
 // faces in the dark Elden Ring-like value structure instead of letting the
 // pale-decay palette wash them into a white wall at driving height.
 float signal_x=18.0*sin(800.0*.012)+4.0*sin(800.0*.033);
 float endpoint_cliff=(1.0-smoothstep(18.0,118.0,length(world_pos.xz-vec2(signal_x,-650.0))))*slope;
 ALBEDO*=mix(vec3(1.0),vec3(.20,.18,.16),endpoint_cliff*.92);
 // Scanned growth supplies microstructure; pigment belongs to this alien watershed.
 vec3 growth_scan=texture(grass_detail,world_pos.xz*.65).rgb;
 float growth_luma=dot(growth_scan,vec3(.2126,.7152,.0722));
 vec3 lichen=mix(mix(mix(vec3(.27,.36,.34),vec3(.32,.24,.16),ember),vec3(.095,.23,.20),marsh),vec3(.29,.23,.28),decay);
 vec3 meadow=lichen*(.63+growth_luma*.92);
 float meadow_density=shoulder*(1.0-slope)*smoothstep(.25,.58,flow);
 meadow_density*=mix(.82,.40,decay)*mix(1.0,.70,ember*(1.0-marsh));
 ALBEDO=mix(ALBEDO*1.15,meadow,meadow_density*.67);
 float shore_distance=basin_distance;
 float water_depth=water_level-world_pos.y;
 float wet_rim=(1.0-smoothstep(1.0,1.45,shore_distance))*(1.0-smoothstep(.0,.85,-water_depth));
 float silt=(1.0-smoothstep(1.1,1.7,shore_distance))*(1.0-smoothstep(.30,1.6,-water_depth));
 vec3 sediment=wetgrain*vec3(.77,.71,.58);
 ALBEDO=mix(ALBEDO,sediment,silt*.78);
 float moisture=max(wet_rim,smoothstep(.55,.83,flow)*marsh*(1.0-decay)*shoulder*.65);
 ALBEDO*=mix(1.0,.66,moisture);
 ROUGHNESS=mix(clamp(.73+texture(rough_map,uv).r*.25,.73,.98),.25,moisture*.88);
 SPECULAR=mix(.20,.34,moisture);
 AO=mix(.76,1.0,smoothstep(.15,.68,gravel.a));
 AO_LIGHT_AFFECT=.32;
 // Dry sediment has its own map. Steep stone projects all three faces in world
 // space, so neither normal scale nor orientation stretches over a cliff.
 vec3 sediment_normal=mix(texture(normal_map,gravel_uv).rgb,texture(wet_normal,gravel_uv).rgb,moisture*.82)*2.0-1.0;
 vec3 detail=vec3(sediment_normal.x,0.0,sediment_normal.y);
 if(slope>.12){
  vec3 nx=texture(rock_normal,world_pos.zy*.28).rgb*2.0-1.0;
  vec3 ny=texture(rock_normal,world_pos.xz*.28).rgb*2.0-1.0;
  vec3 nz=texture(rock_normal,world_pos.xy*.28).rgb*2.0-1.0;
  vec3 rock_perturb=vec3(0.0,nx.y,nx.x)*axes.x+vec3(ny.x,0.0,ny.y)*axes.y+vec3(nz.x,nz.y,0.0)*axes.z;
  detail=mix(detail,rock_perturb,slope);
 }
 vec3 mapped=normalize(world_normal+detail*mix(.32,.19,dust)*(1.0-moisture*.55));
 NORMAL=normalize((VIEW_MATRIX*vec4(mapped,0.0)).xyz);
}

