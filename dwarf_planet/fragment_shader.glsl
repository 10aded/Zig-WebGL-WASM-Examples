#version 100
// Version above obtained by looking at the table at:
// https://en.wikipedia.org/w/index.php?title=OpenGL_Shading_Language&oldid=1270723503

varying highp vec2 TexCoord;

uniform sampler2D uSampler;

void main() {
  highp vec4 texture_color = texture2D(uSampler, TexCoord);
  gl_FragColor = texture_color;
}


// varying highp vec2 vTextureCoord;

//     uniform sampler2D uSampler;

//     void main(void) {
//       gl_FragColor = texture2D(uSampler, vTextureCoord);
//     }
