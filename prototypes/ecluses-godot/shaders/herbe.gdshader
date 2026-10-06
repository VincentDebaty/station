// La prairie derrière les bassins : un vert plus clair en haut, des plaques
// d'herbe plus sombre, des brins, et quelques fleurs blanches et jaunes.
shader_type canvas_item;

uniform vec3 haut : source_color = vec3(0.62, 0.80, 0.39);
uniform vec3 bas : source_color = vec3(0.38, 0.56, 0.24);
uniform float y_haut = 0.0;
uniform float y_bas = 400.0;

varying vec2 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float t = clamp((monde.y - y_haut) / max(y_bas - y_haut, 1.0), 0.0, 1.0);
	vec3 c = mix(haut, bas, t);
	c *= 0.88 + 0.2 * bruit(monde / 70.0) + 0.08 * bruit(monde / 17.0);
	// des brins : de fines rayures verticales, irrégulières
	float brin = bruit(vec2(monde.x * 0.55, monde.y * 0.06));
	c *= 0.93 + 0.12 * smoothstep(0.45, 0.8, brin);
	// des fleurs, rares
	vec2 cel = floor(monde / 26.0);
	vec2 f = fract(monde / 26.0) - vec2(hash(cel), hash(cel + 4.1)) * 0.6 - 0.2;
	float h = hash(cel + 9.3);
	if (h < 0.09 && length(f) < 0.09) {
		c = h < 0.045 ? vec3(0.98, 0.97, 0.92) : vec3(0.98, 0.82, 0.25);
	}
	COLOR = vec4(c, 1.0);
}
