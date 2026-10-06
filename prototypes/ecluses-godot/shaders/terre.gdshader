// La terre en coupe : un brun nuancé, des strates, des cailloux arrondis, et
// une teinte qui s'assombrit en descendant.
shader_type canvas_item;

uniform vec3 clair : source_color = vec3(0.58, 0.40, 0.25);
uniform vec3 sombre : source_color = vec3(0.37, 0.24, 0.15);
uniform vec3 caillou : source_color = vec3(0.70, 0.64, 0.56);
uniform float sol_y = 0.0;   // le haut de la terre, en y monde

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
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * bruit(p); p *= 2.03; a *= 0.5; }
	return s;
}

void fragment() {
	vec2 p = monde / 64.0;
	vec3 c = mix(sombre, clair, fbm(p * 1.4) * 0.95 + 0.05);
	c *= 0.93 + 0.07 * sin(p.y * 5.0 + fbm(p * 0.6) * 5.0);
	// des cailloux, un peu plus d'un tiers des cellules
	vec2 q = p * 1.7;
	vec2 cel = floor(q), fq = fract(q);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 id = cel + o;
			if (hash(id + 7.0) < 0.38) {
				vec2 centre = o + vec2(0.2 + 0.6 * hash(id), 0.2 + 0.6 * hash(id + 1.3));
				vec2 dv = (fq - centre) * vec2(1.0, 1.45);
				float r = 0.07 + 0.11 * hash(id + 2.7);
				float d = length(dv);
				if (d < r) {
					float lumiere = clamp(0.5 - dv.y / r * 0.5 - dv.x / r * 0.2, 0.0, 1.0);
					c = mix(caillou * 0.62, caillou * 1.08, lumiere) * (0.9 + 0.2 * hash(id + 5.0));
				} else if (d < r + 0.025) {
					c *= 0.78;   // l'ombre du caillou dans la terre
				}
			}
		}
	}
	c *= mix(1.0, 0.72, clamp((monde.y - sol_y) / 420.0, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
