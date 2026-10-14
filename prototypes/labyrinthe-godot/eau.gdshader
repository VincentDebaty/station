// L'eau du labyrinthe : chaque bassin est un polygone dont le bord du haut
// suit la surface à ressorts du moteur. Le polygone porte, dans UV :
//   UV.x  l'abscisse, en cases (pour les reflets) ;
//   UV.y  la profondeur sous la surface locale, en cases (0 à la surface).
// Le shader en tire un dégradé (cyan lumineux en surface, bleu plus profond
// vers le fond), un liseré clair d'épaisseur constante à la surface, et
// quelques reflets fins qui glissent juste sous elle. Rien de répétitif :
// deux ondes de fréquences sans rapport simple, lentes.
shader_type canvas_item;

uniform float case_px = 50.0;               // une case, en pixels (pour le liseré)
uniform float lisere_px = 2.5;
uniform vec4 eau_claire : source_color = vec4(0.27, 0.74, 0.98, 1.0);
uniform vec4 eau_fonce : source_color = vec4(0.10, 0.40, 0.85, 1.0);
uniform vec4 lisere : source_color = vec4(0.70, 0.93, 1.0, 1.0);
uniform vec4 reflet : source_color = vec4(0.86, 0.97, 1.0, 1.0);
uniform float profondeur_fonce = 3.0;       // en cases : là où l'eau est la plus foncée
uniform float opacite = 1.0;               // opaque : deux bassins voisins se recouvrent un peu sans liseré de raccord

void fragment() {
	float x = UV.x;
	float p = max(UV.y, 0.0);
	vec4 c = mix(eau_claire, eau_fonce, smoothstep(0.0, profondeur_fonce, p));
	// reflets : de fines bandes claires qui glissent sous la surface et s'effacent en profondeur
	float onde = sin(x * 3.1 + TIME * 0.9 + p * 9.0) * sin(x * 1.7 - TIME * 0.6);
	float bande = smoothstep(0.82, 0.97, onde) * (1.0 - smoothstep(0.08, 0.55, p)) * step(0.06, p);
	c = mix(c, reflet, bande * 0.55);
	// le liseré de surface, d'épaisseur constante à l'écran
	float d_px = p * case_px;
	c = mix(c, lisere, 1.0 - smoothstep(lisere_px - 1.0, lisere_px, d_px));
	COLOR = vec4(c.rgb, opacite);
}
