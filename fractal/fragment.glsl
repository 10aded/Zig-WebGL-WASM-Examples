//#version 330

precision mediump float;

uniform float time;

const float PI = 3.1415926535897932384626433832795;

void main() 
{
    float theta  = 0.8 * time;
    float theta2 = 0.5 * (1.0 + sin(0.25 * PI * time));

    vec2 c   = 0.4 * vec2(cos(theta), sin(theta)) + vec2(0.1, 0.3);
    
    vec2 pos = 1.5 * (2.0 * gl_FragCoord.xy - 500.0) / 500.0;
    
    vec4 color1  = vec4(1,1,1,1);
    vec4 color2  = vec4(0,0,0,1);

    int escape_index = 0;
    vec2 zn = pos;
    
    for (int i = 0; i < 50; i += 1) {
      escape_index += int(length(zn) <= 2.0);
        zn = vec2(zn.x * zn.x - zn.y * zn.y, 2.0 * zn.x * zn.y) - c;
    }
    float escp = log(float(escape_index)) / log(50.0);
    bool in_R = length(zn) <= 2.0;
    
    gl_FragColor = float(in_R) * color1 + float(! in_R) * vec4(escp, 0, theta, 1);
}
