shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;
uniform float world_time=0.0;
uniform float response : hint_range(0.0,1.0)=0.0;
uniform float alarm : hint_range(0.0,1.0)=0.0;
uniform vec2 pool_center;
uniform float water_level;
varying vec3 world_pos;
varying float bed_depth;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 // Barycentric depth from the same clipped terrain triangles as collision.
 bed_depth=COLOR.r*2.0;
}
void fragment(){
 vec2 p=world_pos.xz-pool_center;
 float depth=max(bed_depth,0.0);
 float contact=smoothstep(.004,.14,depth);
 float deep_water=smoothstep(.12,.65,depth);
 float wave_x=cos(p.x*.48+p.y*.81+world_time*.53)*.055+sin(p.x*2.7-p.y*1.2-world_time*.67)*.018;
 float wave_z=sin(p.y*.62-p.x*.29+world_time*.44)*.047+cos(p.y*2.8+p.x*.8-world_time*.56)*.016;
 wave_x*=mix(.20,1.0,deep_water);
 wave_z*=mix(.20,1.0,deep_water);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(vec3(wave_x,1.0,wave_z)),0.0)).xyz);
 float grazing=pow(1.0-max(dot(normalize(VIEW),NORMAL),0.0),4.0);
 float absorption=1.0-exp(-depth*1.8);
 ALBEDO=mix(vec3(.095,.20,.175),vec3(.018,.085,.092),absorption);
 ALBEDO=mix(ALBEDO,vec3(.10,.085,.055),alarm*.18);
 // Clear near the mud contact; the actual probe/sky becomes dominant at grazing
 // angles. A darker bed and broad quiet ripples keep reflections legible.
 ALPHA=contact*clamp(.08+absorption*.28+grazing*.49,0.0,.86);
 float shore_film=(1.0-smoothstep(.035,.18,depth))*smoothstep(.006,.025,depth);
 shore_film*=.45+.35*sin(p.x*1.2+p.y*.7+world_time*.32)*sin(p.y*1.8-p.x*.4);
 ALBEDO=mix(ALBEDO,vec3(.38,.41,.31),shore_film*.25);
 ROUGHNESS=mix(.28,.15,deep_water);
 SPECULAR=mix(.25,.38,deep_water);
 METALLIC=0.0;
 EMISSION=vec3(.006,.022,.014)*response;
}
