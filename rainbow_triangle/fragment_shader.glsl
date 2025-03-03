//#version 330 es

precision mediump float;

varying vec3 Color;

void main() 
{
    gl_FragColor = vec4(Color, 1);
}
