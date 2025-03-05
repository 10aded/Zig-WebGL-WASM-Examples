#version 100
// Version above obtained by looking at the table at:
// https://en.wikipedia.org/w/index.php?title=OpenGL_Shading_Language&oldid=1270723503

varying lowp vec2 TexCoord;

uniform sampler2D uSampler;

void main() {
  lowp vec4 texture_color = texture2D(uSampler, TexCoord);
  gl_FragColor = texture_color;
}
