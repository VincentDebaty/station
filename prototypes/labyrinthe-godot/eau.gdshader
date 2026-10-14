// L'eau du labyrinthe : chaque bassin est un polygone dont le bord du haut
// suit la surface à ressorts du moteur. Le polygone porte, dans UV :
//   UV.x  l'abscisse, en cases (continue d'un bassin à l'autre) ;
//   UV.y  la profondeur sous la surface locale, en cases (0 à la surface).
// D'où :
//   - un dégradé : cyan lumineux en surface, bleu plus profond vers le fond ;
//   - un liseré clair d'épaisseur constante à l'écran, qui scintille par
//     endroits, là où un bruit lent passe un seuil ;
//   - des reflets : de fins traits clairs juste sous la surface, tirés d'un
//     bruit étiré à l'horizontale qui dérive lentement — ils épousent la
//     surface (on les place en profondeur, pas en hauteur) et s'effacent en
//     descendant ; jamais le même motif deux fois ;
//   - en profondeur, des voiles de lumière à peine visibles qui ondulent.
// Le bruit est un hachage sans sinus (stable en précision moyenne sur mobile).
shader_type canvas_item;

uniform float case_px = 50.0;               // une case, en pixels (pour le liseré)
uniform float lisere_px = 2.5;
uniform vec4 eau_claire : source_color = vec4(0.27, 0.74, 0.98, 1.0);
uniform vec4 eau_fonce : source_color = vec4(0.10, 0.40, 0.85, 1.0);
uniform vec4 lisere : source_color = vec4(0.70, 0.93, 1.0, 1.0);
uniform vec4 reflet : source_color = vec4(0.88, 0.98, 1.0, 1.0);
uniform float profondeur_fonce = 3.0;       // en cases : là où l'eau est la plus foncée
uniform float opacite = 1.0;                // opaque : deux bassins voisins se recouvrent un peu sans liseré de raccord

float hachage(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hachage(i), hachage(i + vec2(1.0, 0.0)), u.x),
		mix(hachage(i + vec2(0.0, 1.0)), hachage(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float x = UV.x;
	float p = max(UV.y, 0.0);
	vec4 c = mix(eau_claire, eau_fonce, smoothstep(0.0, profondeur_fonce, p));

	// les reflets : des traits fins, allongés, qui dérivent sous la surface
	float n = bruit(vec2(x * 2.4 + TIME * 0.22, p * 16.0 - TIME * 0.12));
	float n2 = bruit(vec2(x * 5.3 - TIME * 0.37, p * 26.0 + 3.7));
	float trait = smoothstep(0.70, 0.88, n * 0.65 + n2 * 0.35);
	trait *= smoothstep(0.035, 0.08, p) * (1.0 - smoothstep(0.12, 0.5, p));
	c = mix(c, reflet, trait * 0.55);

	// la lumière en profondeur : des voiles très doux qui ondulent
	float voile = bruit(vec2(x * 1.5 + sin(TIME * 0.31 + p * 1.7) * 0.5, p * 1.2 - TIME * 0.18));
	c.rgb += (voile - 0.5) * 0.07 * smoothstep(0.5, 1.6, p);

	// le liseré de surface, d'épaisseur constante, qui scintille par endroits
	float d_px = p * case_px;
	float bord = 1.0 - smoothstep(lisere_px - 1.0, lisere_px, d_px);
	float scintille = smoothstep(0.78, 0.97, bruit(vec2(x * 6.5 + TIME * 0.9, TIME * 0.6)));
	c = mix(c, mix(lisere, vec4(1.0), scintille * 0.8), bord);
	COLOR = vec4(c.rgb, opacite);
}
