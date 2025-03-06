#version 100
// Version above obtained by looking at the table at:
// https://en.wikipedia.org/w/index.php?title=OpenGL_Shading_Language&oldid=1270723503

precision lowp float;

varying lowp vec2 TexCoord;

uniform float lambda;

uniform sampler2D pluto_texture;

mat3 lambda_to_matrix(float l) {
    float norm = 1.0 / (1.0 + 2.0 * l);
    return norm * mat3(1, l, l, l, 1, l, l, l, 1);
}

void main() {
  mat3 lmat = lambda_to_matrix(lambda);
  
  vec4 texture_color = texture2D(pluto_texture, TexCoord);

  vec3 lcolor = lmat * texture_color.xyz;
  gl_FragColor = vec4(lcolor, 1);
}
