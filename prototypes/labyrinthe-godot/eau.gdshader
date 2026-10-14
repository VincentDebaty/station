// L'eau du labyrinthe : une nappe tirée du champ du moteur.
//
// Le champ (la part d'eau de chaque petite case, en texture) est lu en
// B-spline cubique — quatre lectures bilinéaires — pour une surface lisse
// d'un bout à l'autre, sans facettes. Deux images du film sont fondues
// (melange) : l'eau glisse d'une image du moteur à la suivante, même à
// 120 images par seconde. Le bord est un seuil adouci au pixel près ; le
// liseré clair a une épaisseur constante à l'écran, parce qu'on divise
// l'écart au seuil par la pente du champ ; l'eau fonce en profondeur.
shader_type canvas_item;

uniform sampler2D champ_a : filter_linear, repeat_disable;
uniform sampler2D champ_b : filter_linear, repeat_disable;
uniform sampler2D murs : filter_linear, repeat_disable;   // 1 dans un mur : la profondeur le compte comme de l'eau
uniform float melange = 0.0;
uniform vec2 taille = vec2(32.0, 44.0);    // petites cases, en largeur et en hauteur
uniform float finesse = 4.0;               // petites cases par case du labyrinthe
uniform float seuil = 0.5;
uniform float lisere_px = 3.0;             // épaisseur du liseré, en pixels
uniform vec4 eau_claire : source_color = vec4(0.231, 0.682, 0.965, 1.0);
uniform vec4 eau_fonce : source_color = vec4(0.11, 0.42, 0.86, 1.0);
uniform vec4 lisere : source_color = vec4(0.62, 0.89, 1.0, 1.0);

float bspline(sampler2D t, vec2 uv) {
	vec2 tc = uv * taille - 0.5;
	vec2 i = floor(tc);
	vec2 f = tc - i;
	vec2 f2 = f * f, f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1, g1 = w2 + w3;
	vec2 h0 = (i - 1.0 + w1 / g0 + 0.5) / taille;
	vec2 h1 = (i + 1.0 + w3 / g1 + 0.5) / taille;
	float a = texture(t, vec2(h0.x, h0.y)).r;
	float b = texture(t, vec2(h1.x, h0.y)).r;
	float c = texture(t, vec2(h0.x, h1.y)).r;
	float d = texture(t, vec2(h1.x, h1.y)).r;
	return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

float champ(vec2 uv) {
	return mix(bspline(champ_a, uv), bspline(champ_b, uv), melange);
}

void fragment() {
	float v = champ(UV);
	float pente = max(length(vec2(dFdx(v), dFdy(v))), 1e-5);
	float d = (v - seuil) / pente;                       // distance au bord, en pixels (>0 dans l'eau)
	float dedans = clamp(d + 0.5, 0.0, 1.0);             // bord adouci sur un pixel
	if (dedans <= 0.0) {
		discard;
	}
	// la profondeur : l'eau (ou le mur, sous un plafond) qu'il y a au-dessus,
	// de 0,25 à 2 cases — huit lectures, pour un dégradé sans paliers
	float pas_uv = finesse * 0.25 / taille.y;
	float p = 0.0;
	for (int k = 1; k <= 8; k++) {
		vec2 q = UV - vec2(0.0, pas_uv * float(k));
		float dessus = max(champ(q), texture(murs, q).r);
		p += clamp((dessus - 0.3) / 0.4, 0.0, 1.0);
	}
	vec4 c = mix(eau_claire, eau_fonce, smoothstep(0.0, 1.0, p * 0.125));
	c = mix(c, lisere, 1.0 - smoothstep(lisere_px - 1.0, lisere_px, d));
	COLOR = vec4(c.rgb, dedans);
}
