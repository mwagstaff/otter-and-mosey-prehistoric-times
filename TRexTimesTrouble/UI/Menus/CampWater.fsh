// Locations measured on the 900 x 600 reference painting of camp.
float patch(vec2 p, vec2 centre, vec2 radius) {
    vec2 d = (p - centre) / radius;
    return 1.0 - smoothstep(0.45, 1.0, dot(d, d));
}
vec2 campUV(vec2 p) { return vec2(p.x / 900.0, 1.0 - p.y / 600.0); }
void main() {
    vec2 p = vec2(v_tex_coord.x * 900.0, (1.0 - v_tex_coord.y) * 600.0);
    float t = u_time;
    float lake = patch(p, vec2(499.0, 330.0), vec2(134.0, 32.0));
    float cloud = patch(p, vec2(455.0, 73.0), vec2(113.0, 53.0));
    float leaves = max(patch(p, vec2(135.0, 78.0), vec2(83.0, 65.0)),
                       patch(p, vec2(844.0, 124.0), vec2(59.0, 70.0)));
    float flame = patch(p, vec2(204.0, 415.0), vec2(19.0, 21.0));
    float breeze = sin(t * 0.8 + p.x * 0.014);
    float ripple = sin(t * 1.5 - p.y * 0.45 + p.x * 0.027);
    vec2 offset = lake * vec2(0.55, 1.65) * ripple + leaves * vec2(2.9, 1.5) * breeze
                + cloud * vec2(5.0, -0.6) * sin(t * 0.16)
                + flame * vec2(sin(p.y * 0.21 - t * 3.7), 1.5 * sin(t * 3.2 + p.x * 0.3));
    vec4 color = texture2D(u_texture, campUV(p + offset));
    color.rgb += vec3(1.0, 0.76, 0.40) * (0.033 * lake * max(0.0, ripple)
                 + flame * (0.05 + 0.04 * sin(t * 4.2 + p.y * 0.19)));
    vec2 sun = p - vec2(805.0, 163.0);
    color.rgb += vec3(0.09, 0.064, 0.031) * (0.86 + 0.14 * sin(t * 0.4)) *
                 (exp(-dot(sun,sun) / 490.0) + 0.28 * patch(sun, vec2(-89.0, 34.0), vec2(9.0)));
    gl_FragColor = color;
}
