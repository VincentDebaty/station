// La pierre taillée des écluses : des blocs en quinconce, chacun de sa teinte,
// biseautés (haut et gauche éclairés, bas et droite dans l'ombre), joints de
// mortier. « ombre » assombrit les murs du fond, derrière l'eau.
shader_type canvas_item;

uniform vec3 teinte : source_color = vec3(0.90, 0.84, 0.72);
uniform vec3 mortier : source_color = vec3(0.60, 0.53, 0.43);
uniform float ombre = 1.0;
uniform vec2 bloc = vec2(62.0, 31.0);

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
	vec2 p = monde / bloc;
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 id = floor(p);
	vec2 f = fract(p) * bloc;               // position dans le bloc, en pixels
	vec2 g = bloc - f;
	float bord = min(min(f.x, g.x), min(f.y, g.y));
	vec3 c = teinte * (0.9 + 0.2 * hash(id)) * (0.92 + 0.12 * bruit(monde / 9.0));
	c += vec3(0.07) * (1.0 - smoothstep(0.0, 5.0, f.y)) + vec3(0.05) * (1.0 - smoothstep(0.0, 5.0, f.x));
	c -= vec3(0.10) * (1.0 - smoothstep(0.0, 6.0, g.y)) + vec3(0.06) * (1.0 - smoothstep(0.0, 5.0, g.x));
	c = mix(mortier, c, smoothstep(1.0, 2.6, bord));
	COLOR = vec4(c * ombre, 1.0);
}
