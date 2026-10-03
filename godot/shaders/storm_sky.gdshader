shader_type sky;
// Authored dawn illumination; no attenuated panorama or incompatible post effect.
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 vec3 d=normalize(EYEDIR);
 float horizon=pow(1.0-max(d.y,0.0),2.6);
 vec3 col=mix(vec3(.075,.12,.14),vec3(.39,.44,.39),horizon);
 vec3 sun_dir=normalize(vec3(-.62,.47,-.62));
 float sun_axis=max(dot(d,sun_dir),0.0);
 col+=vec3(.38,.22,.055)*pow(sun_axis,6.0);
 col=mix(col,vec3(1.0,.78,.36),smoothstep(.9992,.9996,sun_axis));
 vec2 p=d.xz/max(.24,d.y+.28);
 float cloud=noise(p*vec2(.9,2.8))*.55+noise(p*vec2(2.7,8.4))*.30+noise(p*vec2(7.1,17.0))*.15;
 float veil=smoothstep(.46,.73,cloud)*smoothstep(-.08,.16,d.y);
 vec3 cloud_color=mix(vec3(.18,.24,.24),vec3(.56,.55,.45),smoothstep(.43,.77,cloud));
 col=mix(col,cloud_color,veil*.48);
 // A quiet crescent companion leaves the ecological landmarks in charge.
 vec3 moon_dir=normalize(vec3(.55,.46,-.78));
 float disk=smoothstep(.9979,.9981,dot(d,moon_dir));
 float shade=smoothstep(.25,.77,noise(d.xz*180.0));
 col=mix(col,vec3(.52,.59,.58)*(1.0-shade*.20),disk*.44);
 float aurora=exp(-pow((d.y-.29-.035*sin(d.x*7.0))/.019,2.0));
 col+=vec3(.005,.033,.019)*aurora*noise(d.xz*14.0);
 COLOR=col;
}

