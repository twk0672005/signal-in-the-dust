shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float progress = 0.0;
uniform float elapsed = 0.0;
void fragment() {
    float front=progress*1.22;
    if (UV.x>front || progress<.005) discard;
    float pulse=.62+.38*sin(UV.x*40.0-elapsed*2.3);
    float edge=pow(max(0.0,1.0-abs(UV.y-.5)*2.0),.7);
    if (edge<.1) discard;
    vec3 light=vec3(.08,.54,.60)*pulse*(.55+edge*.45);
    ALBEDO=light;
    EMISSION=light*.5;
}
