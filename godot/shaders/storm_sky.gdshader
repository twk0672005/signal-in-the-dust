shader_type sky;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky() {
    vec3 d=normalize(EYEDIR);
    float horizon=pow(1.0-max(d.y,0.0),4.0);
    vec3 zenith=vec3(.05,.061,.13);
    vec3 low=vec3(.24,.23,.285);
    vec2 p=vec2(d.x*9.0+d.z*3.0,d.y*12.0);
    float clouds=noise(p*2.0)*.6+noise(p*5.0)*.28+noise(p*11.0)*.12;
    float wall=smoothstep(-.07,.06,d.y)*(1.0-smoothstep(.18,.46,d.y+clouds*.07));
    float west=smoothstep(-.4,.6,-d.x);
    vec3 col=mix(zenith,low,horizon);
    col=mix(col,vec3(.10,.12,.225)*(0.55+clouds*1.25),wall*(.52+west*.37));
    vec3 sun_dir=normalize(vec3(-.72,.16,-.48));
    float sun=max(dot(d,sun_dir),0.0);
    col+=vec3(.82,.35,.11)*pow(sun,90.0)*.15;
    col+=vec3(1.0,.73,.4)*smoothstep(.99985,.99996,sun)*.9;
    COLOR=col;
}
