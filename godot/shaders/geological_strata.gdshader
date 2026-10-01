shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D basalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D structure_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform bool organic_surface = false;
uniform float surface_roughness : hint_range(0.3,1.0) = 0.82;
uniform bool roughness_alpha = true;
varying vec3 wp;
varying vec3 wn;
varying vec4 tint;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);tint=COLOR;}
void fragment(){
 vec3 blend=pow(abs(wn),vec3(4.0));blend/=max(dot(blend,vec3(1.0)),.001);
 vec3 tex=texture(basalt_map,wp.yz*.36).rgb*blend.x+texture(basalt_map,wp.xz*.36).rgb*blend.y+texture(basalt_map,wp.xy*.36).rgb*blend.z;
 float fault=noise(wp.xz*.043);
 float layers=noise(vec2(wp.y*.022+fault*.9,wp.x*.015+wp.z*.009))*.64+noise(vec2(wp.y*.049,wp.x*.018+wp.z*.013))*.36;
 float band=smoothstep(.42,.72,layers);
 float fracture=pow(noise(vec2(wp.x*.15+wp.z*.06,wp.y*.24)),2.0);
 // Sub-metre grain belongs to close stone. Unfiltered noise on distant ridges
 // aliases into bright stipple even when the scanned maps use proper mipmaps.
 float close_detail=1.0-smoothstep(18.0,65.0,distance(wp,INV_VIEW_MATRIX[3].xyz));
 float mineral=mix(.5,noise(wp.xz*1.65+wp.y*.24)*.6+noise(wp.xy*4.0-wp.z*.3)*.4,close_detail);
 vec3 stone=mix(vec3(.105,.119,.13),vec3(.16,.135,.113),band*.37+fault*.13);
 float cap=smoothstep(.62,.95,wn.y);
 stone=mix(stone,vec3(.205,.195,.17),cap*.29);
 if(use_vertex_color){stone=tint.rgb*(.82+cap*.18)*(1.0-fracture*.08);}
 ALBEDO=stone*surface_tint.rgb*(.67+tex*1.20)*(1.0-fracture*.18);
 if(use_vertex_color){ALBEDO*=mix(.86,1.08,mineral);}
 float cap_tissue=smoothstep(1.03,1.14,tint.b/max(tint.g,.01));
 if(organic_surface){ALBEDO=tint.rgb*surface_tint.rgb*mix(.67+tex*1.0,vec3(.84+mineral*.17),cap_tissue);}
 vec3 normal_x=texture(structure_normal,wp.zy*.36).xyz*2.0-1.0;
 vec3 normal_y=texture(structure_normal,wp.xz*.36).xyz*2.0-1.0;
 vec3 normal_z=texture(structure_normal,wp.xy*.36).xyz*2.0-1.0;
 vec3 perturb=vec3(0.0,normal_x.y,normal_x.x)*blend.x+vec3(normal_y.x,0.0,normal_y.y)*blend.y+vec3(normal_z.x,normal_z.y,0.0)*blend.z;
 float detail=(organic_surface?mix(.18,.06,cap_tissue):.20)*mix(.15,1.0,close_detail);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(wn+perturb*detail),0.0)).xyz);
 vec4 rough_sample=texture(rough_map,wp.xz*.36);
 ROUGHNESS=clamp(surface_roughness+((roughness_alpha?rough_sample.a:rough_sample.r)-.5)*.16,.38,.98);
 if(organic_surface){ROUGHNESS=clamp(surface_roughness+(mineral-.5)*.08,.38,.96);BACKLIGHT=tint.rgb*.025;}
 SPECULAR=organic_surface?.20:.24;
}

