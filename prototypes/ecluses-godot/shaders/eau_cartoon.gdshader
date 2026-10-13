// L'eau d'un bassin, en dessin animé (essai du 13 octobre 2026, pour la
// planche de comparaison demandée par Vincent, d'après « Jetez-vous à l'eau ») :
// des aplats francs au lieu de la transparence, un trait foncé au bord, des
// reflets blancs en tirets. Ne lit pas l'écran : bien moins cher sur un
// téléphone d'entrée de gamme. Mêmes paramètres que eau.gdshader.
// ECLUSES_STYLE=cartoon le met à la place de l'eau réaliste.
shader_type canvas_item;

uniform vec3 clair : source_color = vec3(0.02, 0.80, 0.98);   // mesuré sur l'image cible : RVB 5, 204, 250
uniform vec3 profond : source_color = vec3(0.0, 0.57, 0.85);  // et 0, 146, 216 au fond
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

// des reflets comme sur l'image cible : de courts traits blancs ondulés,
// irréguliers, plus nombreux près de la surface ; chaque rang a son pas
float vague(float px, float y0, float x, float t, float pas, float graine) {
	float y = y0 + 1.6 * sin(x * 0.06 + t * 1.4 + graine);
	float ligne = 1.0 - smoothstep(0.6, 1.5, abs(px - y));
	float u = x / pas + t * 0.025 + graine;
	float cel = floor(u);
	float h = fract(sin(cel * 91.7 + graine * 13.1) * 43758.5453);
	float f = fract(u);
	// un trait de longueur variable (25 à 55 % du pas), et parfois rien
	float longueur = mix(0.25, 0.55, h);
	float morceau = smoothstep(0.0, 0.06, f) * (1.0 - smoothstep(longueur - 0.06, longueur, f)) * step(0.15, h);
	return ligne * morceau;
}

void fragment() {
	float px = clamp(UV.y, 0.0, 1.0) * epaisseur;
	// un cyan franc qui fonce doucement vers le fond (sur l'image cible :
	// sans trait noir, sans bande marquée)
	vec3 c = mix(clair, profond, clamp(px / 75.0, 0.0, 1.0));
	// les reflets : des lignes blanches fines et ondulées
	float v = vague(px, 9.0, monde.x, TIME, 110.0, 0.0) * 0.95
		+ vague(px, 21.0, monde.x + 40.0, TIME, 130.0, 1.7) * 0.75
		+ vague(px, 36.0, monde.x + 90.0, TIME, 160.0, 3.1) * 0.45;
	c = mix(c, vec3(1.0), clamp(v, 0.0, 1.0));
	// l'eau qui bouillonne : des ronds blancs
	vec2 g = monde / 16.0 + vec2(0.0, TIME * 1.5);
	vec2 cel = floor(g);
	float h = fract(sin(dot(cel, vec2(12.9898, 78.233))) * 43758.5453);
	float rond = step(0.7, h) * (1.0 - smoothstep(0.18, 0.26, length(fract(g) - 0.5)));
	c = mix(c, vec3(1.0), rond * remous * 0.8 * (1.0 - smoothstep(10.0, 50.0, px)));
	// (pas de liseré à la surface de la coupe : le dessus de l'eau, de la même
	// couleur, la prolonge jusqu'au mur ; le liseré est au fond, canal.gd)
	COLOR = vec4(c, 1.0);
}
