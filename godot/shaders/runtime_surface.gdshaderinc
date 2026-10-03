// Project PBR surface. Render semantics are selected by runtime_surface.gd;
// texture presence and scalar/tint differences share this same program.
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness = 1.0;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 roughness_channel = vec4(1.0,0.0,0.0,0.0);
uniform float metallic = 0.0;
uniform float metallic_specular = .5;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_channel = vec4(1.0,0.0,0.0,0.0);
uniform bool normal_enabled = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 1.0;
uniform bool ao_enabled = false;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ao_channel = vec4(1.0,0.0,0.0,0.0);
uniform float ao_light_affect = 0.0;
uniform bool ao_on_uv2 = false;
uniform bool emission_enabled = false;
uniform vec4 emission : source_color = vec4(0.0);
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float emission_energy_multiplier = 1.0;
uniform bool emission_multiply = false;
uniform bool emission_on_uv2 = false;
uniform bool vertex_color_use_as_albedo = false;
uniform bool vertex_color_is_srgb = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform bool uv1_triplanar = false;
uniform bool uv1_world_triplanar = false;
uniform float uv1_triplanar_sharpness = 1.0;
uniform vec3 uv2_scale = vec3(1.0);
uniform vec3 uv2_offset = vec3(0.0);
uniform bool uv2_triplanar = false;
uniform bool uv2_world_triplanar = false;
uniform float uv2_triplanar_sharpness = 1.0;
uniform float alpha_scissor_threshold = .5;
varying vec3 tri_pos1;
varying vec3 tri_weights1;
varying vec3 tri_pos2;
varying vec3 tri_weights2;

vec3 linear_vertex_color(vec3 color) {
	return mix(pow((color+vec3(.055))/1.055,vec3(2.4)),color/12.92,lessThan(color,vec3(.04045)));
}

vec3 srgb_vertex_color(vec3 color) {
	return mix(1.055*pow(max(color,vec3(0.0)),vec3(1.0/2.4))-.055,12.92*color,lessThan(color,vec3(.0031308)));
}

void vertex() {
	if (vertex_color_is_srgb && !OUTPUT_IS_SRGB) COLOR.rgb = linear_vertex_color(COLOR.rgb);
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	UV2 = UV2 * uv2_scale.xy + uv2_offset.xy;
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	vec3 n1 = uv1_world_triplanar ? MODEL_NORMAL_MATRIX * NORMAL : NORMAL;
	vec3 n2 = uv2_world_triplanar ? mat3(MODEL_MATRIX) * NORMAL : NORMAL;
	tri_pos1 = ((uv1_world_triplanar ? world_p : VERTEX) * uv1_scale + uv1_offset) * vec3(1.0,-1.0,1.0);
	tri_pos2 = ((uv2_world_triplanar ? world_p : VERTEX) * uv2_scale + uv2_offset) * vec3(1.0,-1.0,1.0);
	tri_weights1 = pow(abs(n1),vec3(uv1_triplanar_sharpness));
	tri_weights1 /= max(dot(tri_weights1,vec3(1.0)),.00001);
	tri_weights2 = pow(abs(n2),vec3(uv2_triplanar_sharpness));
	tri_weights2 /= max(dot(tri_weights2,vec3(1.0)),.00001);
#ifndef SURFACE_UNSHADED
	if (uv1_triplanar || uv2_triplanar) {
		// Same projection frame used by the pinned BaseMaterial3D generator.
		vec3 t = vec3(0.0,0.0,-1.0)*abs(n1.x)+vec3(1.0,0.0,0.0)*(abs(n1.y)+abs(n1.z));
		vec3 b = vec3(0.0,1.0,0.0)*(abs(n1.x)+abs(n1.z))+vec3(0.0,0.0,-1.0)*abs(n1.y);
		TANGENT = normalize(t);
		BINORMAL = normalize(b);
		if (uv1_world_triplanar) {
			TANGENT = inverse(MODEL_NORMAL_MATRIX) * TANGENT;
			BINORMAL = inverse(MODEL_NORMAL_MATRIX) * BINORMAL;
		}
	}
#endif
}

vec4 surface_sample(sampler2D tex, bool second, vec2 uv) {
	bool triplanar = second ? uv2_triplanar : uv1_triplanar;
	if (!triplanar) return texture(tex,uv);
	vec3 p = second ? tri_pos2 : tri_pos1;
	vec3 w = second ? tri_weights2 : tri_weights1;
	return texture(tex,p.xy)*w.z + texture(tex,p.xz)*w.y + texture(tex,p.zy*vec2(-1.0,1.0))*w.x;
}

void fragment() {
	vec4 color = surface_sample(albedo_texture,false,UV);
	ALBEDO = albedo_color.rgb * color.rgb;
	if (vertex_color_use_as_albedo) {
		// GLES3 decodes ALBEDO after fragment(); glTF COLOR_0 multiplies in linear.
		// Convert after interpolation and leave explicitly sRGB colour behavior intact.
		if (OUTPUT_IS_SRGB && !vertex_color_is_srgb) ALBEDO = srgb_vertex_color(linear_vertex_color(ALBEDO) * COLOR.rgb);
		else ALBEDO *= COLOR.rgb;
		color.a *= COLOR.a;
	}
#ifndef SURFACE_UNSHADED
	ROUGHNESS = roughness * dot(surface_sample(roughness_texture,false,UV),roughness_channel);
	METALLIC = metallic * dot(surface_sample(metallic_texture,false,UV),metallic_channel);
	SPECULAR = metallic_specular;
	NORMAL_MAP = normal_enabled ? surface_sample(normal_texture,false,UV).rgb : vec3(.5,.5,1.0);
	NORMAL_MAP_DEPTH = normal_enabled ? normal_scale : 0.0;
	AO = ao_enabled ? dot(surface_sample(ao_texture,ao_on_uv2,ao_on_uv2 ? UV2 : UV),ao_channel) : 1.0;
	AO_LIGHT_AFFECT = ao_enabled ? ao_light_affect : 0.0;
#endif
	if (emission_enabled) {
		vec3 map = surface_sample(emission_texture,emission_on_uv2,emission_on_uv2 ? UV2 : UV).rgb;
		EMISSION = (emission_multiply ? emission.rgb*map : emission.rgb+map) * emission_energy_multiplier;
	}
#ifdef SURFACE_ALPHA
	ALPHA = albedo_color.a * color.a;
#endif
#ifdef SURFACE_SCISSOR
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
#endif
}
