#version 100
// Version above obtained by looking at the table at:
// https://en.wikipedia.org/w/index.php?title=OpenGL_Shading_Language&oldid=1270723503

precision mediump float;

varying vec3 Color;

void main() 
{
    gl_FragColor = vec4(Color, 1);
}
