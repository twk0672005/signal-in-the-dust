shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec4 tint : source_color = vec4(.3,.35,.34,1.0);
uniform float roughness = .82;
uniform float shell = 0.0;
uniform float membrane = 0.0;
uniform float glow = 0.0;
uniform float response = 1.0;
uniform float shell_uv = 0.0;
uniform float wing_flex = 0.0;
uniform float specular_amount = 0.35;
varying vec3 local_p;
float hash3(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float tissue(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),
                   mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),
                   mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
    local_p = VERTEX;
    float span = smoothstep(0.15,2.2,abs(VERTEX.x));
    VERTEX.z += wing_flex * span * span;
    VERTEX.y += wing_flex * span * 0.28;
}
void fragment() {
    // Body-scale pigment, with fine detail confined mainly to roughness.
    // Low contrast preserves the authored scute, muscle and wing curvature.
    vec3 p = local_p;
    float broad = tissue(p * 1.55 + vec3(1.3,3.1,0.7));
    float mineral = tissue(p * 7.0 + vec3(4.7,1.9,7.2));
    float footprint = max(length(dFdx(p)),length(dFdy(p)));
    float detail_visibility = 1.0 - smoothstep(0.012,0.055,footprint);
    float grain = mix(0.5,tissue(p * 23.0),detail_visibility);
    float growth_coordinate = mix(p.y*14.0+p.z*2.0,UV.y*34.0,shell_uv);
    float stratum = 0.5 + 0.5 * sin(growth_coordinate + broad*2.0 + mineral*0.45);
    float band_visibility = 1.0 - smoothstep(0.4,2.2,fwidth(growth_coordinate));
    stratum = mix(0.5,stratum,band_visibility);
    float shell_pattern = mix(0.85,1.04,broad) * mix(0.95,1.02,mineral)
                          * mix(0.955,1.0,stratum);
    // The authored scute UV runs from its apex to its lip. Darker growth at
    // that lip makes overlapping shields legible without painting fake cracks.
    shell_pattern *= mix(1.0,0.77,shell_uv*smoothstep(0.68,0.98,UV.y));
    float skin_pattern = mix(0.90,1.04,broad);
    float membrane_reach = smoothstep(0.08,1.5,length(p*vec3(1.0,0.65,0.4)));
    float membrane_pattern = mix(0.85,1.06,broad) * mix(0.84,1.08,membrane_reach);
    float pattern = mix(mix(skin_pattern,shell_pattern,shell),membrane_pattern,membrane);
    // Pale ridges and quiet ochre mineral deposits share the terrain palette.
    vec3 pigment = mix(tint.rgb,tint.rgb*vec3(1.08,1.015,0.91),shell*(1.0-membrane)*mineral*0.35);
    ALBEDO = pigment * pattern;
    ROUGHNESS = clamp(roughness + (grain-0.5)*0.07 + shell*(1.0-stratum)*0.025,0.18,0.98);
    METALLIC = 0.0;
    SPECULAR = specular_amount;
    EMISSION = tint.rgb * glow * response;
    // Submillimetre relief; distant derivatives fade out before they shimmer.
    float relief = ((grain-0.5)*0.0011 + (mineral-0.5)*0.0018*shell
                    + stratum*0.0005*shell) * (1.0-membrane*0.92);
    vec3 n = normalize(NORMAL);
    if (!FRONT_FACING) { n = -n; }
    vec3 dx = dFdx(VERTEX);
    vec3 dy = dFdy(VERTEX);
    vec3 rx = cross(dy,n);
    vec3 ry = cross(n,dx);
    float determinant = dot(dx,rx);
    vec3 gradient = dFdx(relief)*rx + dFdy(relief)*ry;
    NORMAL = normalize(abs(determinant)*n - sign(determinant)*gradient);
}
