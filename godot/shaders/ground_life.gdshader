shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float world_time=0.0;
varying vec4 tone;
void vertex(){
 tone=COLOR;
 VERTEX.x+=sin(world_time*.8+VERTEX.z*.32+VERTEX.x*.4)*max(VERTEX.y,0.0)*.015;
}
void fragment(){
 float vein=pow(max(0.0,1.0-abs(UV.x-.5)*18.0),2.0);
 ALBEDO=tone.rgb*(.6+.4*sin(UV.y*7.0));ROUGHNESS=.7;SPECULAR=.22;
 EMISSION=tone.rgb*vein*.12;
}
