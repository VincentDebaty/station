// L'eau d'un bassin. Le maillage est une bande : UV.y vaut 0 à la surface et
// 1 au fond, UV.x suit la largeur. Elle réfracte ce qui est derrière elle (le
// mur du fond, la coque immergée des bateaux), s'assombrit avec la
// profondeur, porte des reflets mouvants (caustiques) et une ligne d'écume.
shader_type canvas_item;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform vec3 clair : source_color = vec3(0.18, 0.78, 0.90);
uniform vec3 profond : source_color = vec3(0.02, 0.36, 0.56);
uniform vec3 ecume : source_color = vec3(0.86, 0.98, 1.0);
uniform float epaisseur = 120.0;   // hauteur d'eau en pixels, pour doser
uniform float remous = 0.0;        // 0 au repos, 1 quand l'eau bouillonne

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
float caustique(vec2 p, float t) {
	vec2 q = p;
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		q = vec2(q.x + 0.55 * sin(q.y * 1.6 + t * 0.7 + fi), q.y + 0.55 * cos(q.x * 1.3 - t * 0.55 + fi * 1.7));
		c += 1.0 / (1.0 + 14.0 * abs(sin(q.x * 2.1) * sin(q.y * 2.3)));
	}
	return pow(c / 3.0, 2.6);
}

void fragment() {
	float prof = clamp(UV.y, 0.0, 1.0);
	float px = prof * epaisseur;                       // distance à la surface, en pixels
	vec3 c = mix(clair, profond, pow(prof, 0.75) * clamp(epaisseur / 260.0, 0.35, 1.0));

	// ce qui est derrière, vu à travers une eau qui ondule
	vec2 d = vec2(sin(monde.y * 0.09 + TIME * 2.1), cos(monde.x * 0.07 + TIME * 1.6)) * (0.0035 + 0.004 * remous);
	vec3 derriere = texture(ecran, SCREEN_UV + d).rgb;
	float transparence = mix(0.34, 0.06, clamp(px / 140.0, 0.0, 1.0));
	c = mix(c, derriere * vec3(0.30, 0.70, 0.84), transparence);

	// reflets mouvants, plus forts près de la surface
	float k = caustique(monde / 46.0, TIME * 1.1);
	c += vec3(0.85, 1.0, 1.0) * k * 0.26 * (1.0 - prof * 0.5);

	// l'eau qui bouillonne blanchit par plaques
	float mousse = smoothstep(0.62, 0.9, bruit(monde / 22.0 + vec2(TIME * 1.3, -TIME * 2.0))) * remous;
	c = mix(c, ecume, mousse * 0.45 * (1.0 - prof));

	// la ligne de surface : un liseré clair, puis une bande plus douce
	float liser = 1.0 - smoothstep(1.5, 3.5, px);
	float bande = 1.0 - smoothstep(3.0, 14.0, px);
	c = mix(c, ecume, liser * 0.9 + bande * 0.18);

	COLOR = vec4(c, 0.96);
}
