// La nappe d'une cascade. Le ruban porte, dans UV :
//   UV.x  la distance parcourue depuis le seuil, en cases ;
//   UV.y  la position en travers, de −1 (un bord) à +1 (l'autre).
// et dans COLOR.a son intensité (le débit, déjà lissé).
// Le cœur est d'un bleu clair un peu plus soutenu, les bords s'éclaircissent
// et s'adoucissent ; des stries claires descendent avec l'eau, plus vite en
// bas qu'en haut (l'eau accélère en tombant). Un filet faible est transparent.
shader_type canvas_item;

uniform vec4 coeur : source_color = vec4(0.36, 0.78, 1.0, 1.0);
uniform vec4 bord : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform vec4 strie : source_color = vec4(0.93, 0.99, 1.0, 1.0);

void fragment() {
	float travers = abs(UV.y);
	float l = UV.x;
	vec4 c = mix(coeur, bord, smoothstep(0.35, 1.0, travers));
	// des stries qui descendent : leur phase avance avec le temps, et plus vite plus bas
	float s = sin(l * 11.0 - TIME * (9.0 + 6.0 * l) + UV.y * 2.5) * sin(l * 4.3 - TIME * 5.0 - UV.y * 1.7);
	c = mix(c, strie, smoothstep(0.55, 0.95, s) * 0.6);
	float bords_doux = 1.0 - smoothstep(0.75, 1.0, travers);
	COLOR = vec4(c.rgb, COLOR.a * bords_doux);
}
