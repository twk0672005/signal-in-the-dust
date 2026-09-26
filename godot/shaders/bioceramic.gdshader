shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(.15,.22,.25,1.0);
uniform float softness = 0.0;
uniform float glow = 0.0;
varying vec3 local_p;
void vertex(){local_p=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
 float strata=.5+.5*sin(local_p.y*31.0+sin(local_p.x*14.0+local_p.z*8.0)*2.8);
 float grain=.5+.5*sin(local_p.x*23.0+sin(local_p.z*11.0))*sin(local_p.y*27.0);
 float seams=pow(abs(sin(local_p.x*8.0+local_p.z*9.0+sin(local_p.y*11.0))),20.0);
 ALBEDO=tint.rgb*(.66+.23*strata+.15*grain);
 ROUGHNESS=mix(.65,.39,softness)+.1*(grain-.5);
 METALLIC=.0;SPECULAR=.28;
 EMISSION=tint.rgb*glow*(.45+.55*seams);
}
