// Un jet d'eau : UV.x suit le jet, UV.y le traverse. Des filets clairs qui
// défilent dans le sens du courant, des bords qui s'effilochent.
shader_type canvas_item;

uniform float force = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float u = UV.x, v = UV.y;
	float filets = bruit(vec2(u * 9.0 - TIME * 7.0, v * 7.0)) * 0.6 + bruit(vec2(u * 22.0 - TIME * 13.0, v * 15.0)) * 0.4;
	vec3 c = mix(vec3(0.40, 0.83, 0.94), vec3(0.93, 0.99, 1.0), smoothstep(0.35, 0.85, filets));
	float bord = 1.0 - smoothstep(0.30, 0.5, abs(v - 0.5) + (filets - 0.5) * 0.25);
	float fin = 1.0 - smoothstep(0.82, 1.0, u);
	COLOR = vec4(c, bord * (0.78 + 0.22 * force) * mix(0.6, 1.0, fin));
}
