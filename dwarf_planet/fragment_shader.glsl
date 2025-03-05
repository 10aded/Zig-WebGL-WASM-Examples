#version 100
// Version above obtained by looking at the table at:
// https://en.wikipedia.org/w/index.php?title=OpenGL_Shading_Language&oldid=1270723503

varying vec2 TexCoord;

uniform sampler2D texture0;

precision mediump float;

void main() {
  vec4 texture_color = texture(texture0, TexCoord);
  gl_FragColor = texture_color;
}
