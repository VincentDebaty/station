// L'eau d'un bassin, en dessin animé (essai du 13 octobre 2026, pour la
// planche de comparaison demandée par Vincent, d'après « Jetez-vous à l'eau ») :
// des aplats francs au lieu de la transparence, un trait foncé au bord, des
// reflets blancs en tirets. Ne lit pas l'écran : bien moins cher sur un
// téléphone d'entrée de gamme. Mêmes paramètres que eau.gdshader.
// ECLUSES_STYLE=cartoon le met à la place de l'eau réaliste.
shader_type canvas_item;

uniform vec3 clair : source_color = vec3(0.30, 0.74, 0.95);
uniform vec3 profond : source_color = vec3(0.13, 0.50, 0.84);
uniform vec3 trait : source_color = vec3(0.05, 0.22, 0.42);
uniform float epaisseur = 120.0;
uniform float remous = 0.0;
uniform float largeur = 300.0;
uniform float paroi_g = 1.0;
uniform float paroi_d = 1.0;
uniform float clarte = 0.0;

varying vec2 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float px = clamp(UV.y, 0.0, 1.0) * epaisseur;
	// deux aplats : l'eau claire en haut, plus foncée en bas, avec une
	// frontière douce mais nette, qui ondule à peine
	float frontiere = 34.0 + 6.0 * sin(monde.x * 0.03 + TIME * 0.9);
	vec3 c = mix(clair, profond, smoothstep(frontiere - 3.0, frontiere + 3.0, px));
	// des reflets blancs en tirets, couchés sous la surface, qui glissent
	float tiret = step(0.62, fract(monde.x / 70.0 + TIME * 0.06 + floor(px / 14.0) * 0.37));
	float rang1 = step(7.0, px) * (1.0 - step(10.0, px));
	float rang2 = step(19.0, px) * (1.0 - step(21.5, px)) * step(0.4, fract(monde.x / 130.0 - TIME * 0.04));
	c = mix(c, vec3(1.0), (rang1 * tiret + rang2 * tiret * 0.8) * 0.85);
	// l'eau qui bouillonne : des ronds blancs
	vec2 g = monde / 16.0 + vec2(0.0, TIME * 1.5);
	vec2 cel = floor(g);
	float h = fract(sin(dot(cel, vec2(12.9898, 78.233))) * 43758.5453);
	float rond = step(0.7, h) * (1.0 - smoothstep(0.18, 0.26, length(fract(g) - 0.5)));
	c = mix(c, vec3(1.0), rond * remous * 0.8 * (1.0 - smoothstep(10.0, 50.0, px)));
	// le trait du dessin : sur les parois de pierre, et un filet clair sous la surface
	float bg = UV.x * largeur;
	float bd = (1.0 - UV.x) * largeur;
	float bord = max(paroi_g * (1.0 - step(2.5, bg)), paroi_d * (1.0 - step(2.5, bd)));
	c = mix(c, trait, bord);
	// le trait foncé de la surface, puis un filet clair juste dessous
	c = mix(c, vec3(0.80, 0.96, 1.0), step(2.5, px) * (1.0 - step(5.0, px)) * 0.9);
	c = mix(c, trait, 1.0 - step(2.5, px));
	COLOR = vec4(c, 1.0);
}
