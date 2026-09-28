shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D rock_strip : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment(){
 vec4 rock=texture(rock_strip,UV);
 // Card-only atmospheric perspective retains silhouette while reducing distant
 // contrast; native near geometry and global fog are not blurred or thickened.
 float aerial=smoothstep(190.0,670.0,length(VERTEX))*.66;
 vec3 color=rock.rgb*COLOR.rgb;
 float value=dot(color,vec3(.2126,.7152,.0722));
 color=mix(color,vec3(value),aerial*.45);
 ALBEDO=mix(color,vec3(.38,.465,.51),aerial);
 ALPHA=rock.a;
 ALPHA_SCISSOR_THRESHOLD=.42;
}
