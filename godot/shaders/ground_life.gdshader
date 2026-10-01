shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float world_time=0.0;
uniform sampler2D lamina_albedo : source_color, filter_linear_mipmap;
uniform sampler2D lamina_roughness : hint_default_white, filter_linear_mipmap;
uniform sampler2D lamina_normal : hint_normal, filter_linear_mipmap;
uniform bool mud_surface=false;
uniform sampler2D mud_albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec4 tone;
vec3 linear_vertex_color(vec3 color){
 return mix(pow((color+vec3(.055))/1.055,vec3(2.4)),color/12.92,lessThan(color,vec3(.04045)));
}
vec3 srgb_vertex_color(vec3 color){
 return mix(1.055*pow(max(color,vec3(0.0)),vec3(1.0/2.4))-.055,12.92*color,lessThan(color,vec3(.0031308)));
}
void vertex(){
 tone=COLOR;
 // Reusable closed seedlings bend from local rooted height, never world elevation.
 float bend=clamp(VERTEX.y,0.0,1.8);
 bend*=bend;
 if(!mud_surface){
  VERTEX.x+=sin(world_time*.72+float(INSTANCE_ID)*.71)*bend*.018;
  VERTEX.z+=cos(world_time*.58+float(INSTANCE_ID)*.49)*bend*.013;
 }
}
void fragment(){
 vec3 sampled=mud_surface?texture(mud_albedo,UV).rgb:texture(lamina_albedo,UV).rgb;
 // Same GLES3 contract as runtime_surface: sampled display colour combines
 // with authored linear COLOR after interpolation, then ALBEDO is re-encoded.
 vec3 linear_sample=OUTPUT_IS_SRGB?linear_vertex_color(sampled):sampled;
 vec3 mixed_color=linear_sample*tone.rgb;
 if(mud_surface){
  float grain=clamp(dot(linear_sample,vec3(.2126,.7152,.0722))*1.7,0.0,1.0);
  mixed_color=mix(vec3(.040,.025,.014),vec3(.088,.059,.034),grain)*tone.rgb;
 }
 ALBEDO=OUTPUT_IS_SRGB?srgb_vertex_color(mixed_color):mixed_color;
 ROUGHNESS=mud_surface?.82:clamp(texture(lamina_roughness,UV).r,.55,.88);
 if(!FRONT_FACING) NORMAL=-NORMAL;
 NORMAL_MAP=mud_surface?vec3(.5,.5,1):texture(lamina_normal,UV).rgb;
 NORMAL_MAP_DEPTH=mud_surface?0.0:.16;
 SPECULAR=mud_surface?.12:.24;
 BACKLIGHT=mud_surface?vec3(0.0):tone.rgb*.035;
}
