//#version 300 es
attribute vec2 aPos;
attribute vec3 aColor;
varying   vec3 Color;

precision mediump float;

uniform float time;

void main() {
  mat2 rotation = mat2(cos(time), sin(time), -sin(time), cos(time));
  gl_Position = vec4(rotation * aPos, 0, 1);
  Color = aColor;
}
