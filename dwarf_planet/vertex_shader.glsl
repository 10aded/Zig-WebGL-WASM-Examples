#version 100
// Version above obtained by looking at the table at:
// https://en.wikipedia.org/w/index.php?title=OpenGL_Shading_Language&oldid=1270723503

attribute vec2 aPos;
attribute vec2 aTexCoord;
varying   vec2 TexCoord;

//precision mediump float;

//uniform float time;

void main() {
  gl_Position = vec4(aPos, 0, 1);
  TexCoord = aTexCoord;
}
