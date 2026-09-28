shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float world_time=0.0;
varying vec4 tone;
void vertex(){
 tone=COLOR;
 // UV.y is height relative to each blade root; world elevation must not bend roots.
 float bend=UV.y*UV.y;
 VERTEX.x+=sin(world_time*.8+VERTEX.z*.32+VERTEX.x*.4)*bend*.065;
 VERTEX.z+=cos(world_time*.63+VERTEX.x*.21)*bend*.035;
}
void fragment(){
 float edge=abs(UV.x-.5)*2.0;
 ALBEDO=tone.rgb*mix(.62,.96,clamp(UV.y,0.0,1.0))*(1.0-edge*.035);
 ROUGHNESS=.69;SPECULAR=.27;
 BACKLIGHT=tone.rgb*.085;
}

