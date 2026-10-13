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

// une fine ligne blanche ondulée à « y0 » pixels sous la surface, coupée par
// endroits, qui glisse doucement
float vague(float px, float y0, float x, float t, float decale) {
	float y = y0 + 2.2 * sin(x * 0.045 + t * 1.3 + decale);
	float ligne = 1.0 - smoothstep(0.5, 1.4, abs(px - y));
	float coupe = smoothstep(0.25, 0.45, fract(x / 210.0 + t * 0.03 + decale * 0.31));
	return ligne * coupe;
}

void fragment() {
	float px = clamp(UV.y, 0.0, 1.0) * epaisseur;
	// un cyan franc qui fonce doucement vers le fond (sur l'image cible :
	// sans trait noir, sans bande marquée)
	vec3 c = mix(clair, profond, clamp(px / 75.0, 0.0, 1.0));
	// les reflets : des lignes blanches fines et ondulées
	float v = vague(px, 14.0, monde.x, TIME, 0.0) * 0.85
		+ vague(px, 30.0, monde.x + 60.0, TIME, 1.7) * 0.6
		+ vague(px, 50.0, monde.x + 140.0, TIME, 3.1) * 0.35;
	c = mix(c, vec3(1.0), clamp(v, 0.0, 1.0));
	// l'eau qui bouillonne : des ronds blancs
	vec2 g = monde / 16.0 + vec2(0.0, TIME * 1.5);
	vec2 cel = floor(g);
	float h = fract(sin(dot(cel, vec2(12.9898, 78.233))) * 43758.5453);
	float rond = step(0.7, h) * (1.0 - smoothstep(0.18, 0.26, length(fract(g) - 0.5)));
	c = mix(c, vec3(1.0), rond * remous * 0.8 * (1.0 - smoothstep(10.0, 50.0, px)));
	// la surface : un liseré clair, pas de trait foncé
	c = mix(c, vec3(0.62, 0.95, 1.0), 1.0 - smoothstep(1.0, 3.0, px));
	COLOR = vec4(c, 1.0);
}
