shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 vec3 d=normalize(EYEDIR);
 float horizon=pow(1.0-max(d.y,0.0),3.0);
 vec3 col=mix(vec3(.14,.28,.43),vec3(.53,.61,.65),horizon);
 float warm_axis=smoothstep(-.25,.8,dot(normalize(d.xz+vec2(.0001)),normalize(vec2(.64,.77))));
 col+=vec3(.12,.074,.029)*horizon*(.3+.7*warm_axis);
 vec2 p=d.xz/max(.16,d.y+.18);
 float cloud=noise(p*2.0)*.55+noise(p*5.0)*.28+noise(p*13.0)*.17;
 col=mix(col,vec3(.77,.77,.72),smoothstep(.48,.73,cloud)*.73);
 float curtain=exp(-pow((d.y-.28-.055*sin(d.x*8.0))/ .035,2.0));
 float veil=noise(vec2(d.x*35.0,d.z*5.0));
 col+=vec3(.023,.068,.055)*curtain*veil*smoothstep(-.1,.8,d.z);
 vec3 moon_dir=normalize(vec3(-.52,.50,-.65));
 float disk=dot(d,moon_dir),moon=smoothstep(.9976,.9979,disk);
 float crater=noise(d.xz*260.0)*.22+noise(d.xy*93.0)*.16;
 col+=vec3(.40,.51,.78)*pow(max(disk,0.0),90.0)*.22;
 col=mix(col,vec3(.67,.76,.96)*(1.0-crater),moon);
 vec2 suv=vec2(atan(d.x,d.z),asin(d.y))*260.0;
 float star=step(.9968,hash(floor(suv)))*pow(max(0.0,1.0-length(fract(suv)-.5)*2.0),8.0);
 col+=vec3(.06,.075,.09)*star*smoothstep(.08,.4,d.y)*(1.0-smoothstep(.50,.7,cloud));
 COLOR=col;
}

