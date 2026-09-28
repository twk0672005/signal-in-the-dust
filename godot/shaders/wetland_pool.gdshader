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
 float wave_x=cos(p.x*.70+p.y*1.04+world_time*.53)*.032+sin(p.x*4.3-p.y*1.6-world_time*.67)*.009;
 float wave_z=sin(p.y*.95-p.x*.42+world_time*.44)*.028+cos(p.y*4.1+p.x*.8-world_time*.56)*.008;
 wave_x*=mix(.20,1.0,deep_water);
 wave_z*=mix(.20,1.0,deep_water);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(vec3(wave_x,1.0,wave_z)),0.0)).xyz);
 float grazing=pow(1.0-max(dot(normalize(VIEW),NORMAL),0.0),4.0);
 float absorption=1.0-exp(-depth*1.8);
 ALBEDO=mix(vec3(.20,.25,.19),vec3(.095,.215,.24),absorption);
 ALBEDO=mix(ALBEDO,vec3(.10,.085,.055),alarm*.18);
 ALPHA=contact*clamp(.035+absorption*.52+grazing*.28*deep_water,0.0,.90);
 ROUGHNESS=mix(.24,.085,deep_water);
 SPECULAR=mix(.20,.48,deep_water);
 METALLIC=0.0;
 EMISSION=vec3(.006,.022,.014)*response;
}
