//#version 330

precision mediump float;

void main() 
{
    vec2 pos = 1.5 * (2.0 * gl_FragCoord.xy - 500.0) / 500.0;
    
    vec4 color1  = vec4(1,1,1,1);
    vec4 color2  = vec4(0,0,0,1);

    int escape_index = 0;
    vec2 zn = pos;
    
    for (int i = 0; i < 50; i += 1) {
      escape_index += int(length(zn) <= 2.0);
        zn = vec2(zn.x * zn.x - zn.y * zn.y, 2.0 * zn.x * zn.y) - vec2(0.5, 0.5);
    }
    float escp = log(float(escape_index)) / log(50.0);
    bool in_R = length(zn) <= 2.0;
    
    gl_FragColor = float(in_R) * color1 + float(! in_R) * vec4(escp, 0, escp, 1);
}
