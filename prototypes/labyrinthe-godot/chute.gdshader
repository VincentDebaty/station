// La nappe d'une cascade. Le ruban porte, dans UV :
//   UV.x  la distance parcourue depuis le seuil, en cases ;
//   UV.y  la position en travers, de −1 (un bord) à +1 (l'autre).
//   (−1 : le bord du haut) ;
// dans COLOR.a son intensité (le débit, déjà lissé), et dans COLOR.r 1 si
// elle prolonge l'eau d'un bassin : au départ, sur le bord, elle a alors sa
// couleur, son opacité et son liseré clair en haut — l'eau qui passe le
// bord et l'eau qui tombe ne font qu'un — puis devient nappe en tombant.
// COLOR.g vaut 1 pour un filet presque tari : il s'égrène en gouttes.
// COLOR.b : la profondeur de la lèvre sous la surface de sa masse, sur 8
// cases (la teinte de départ, comme dans eau.gdshader).
// Le cœur est d'un bleu clair un peu plus soutenu, les bords s'éclaircissent
// et s'adoucissent ; des stries claires descendent avec l'eau, plus vite en
// bas qu'en haut (l'eau accélère en tombant). Un filet faible est transparent.
shader_type canvas_item;

uniform vec4 coeur : source_color = vec4(0.36, 0.78, 1.0, 1.0);
uniform vec4 bord : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform vec4 strie : source_color = vec4(0.93, 0.99, 1.0, 1.0);
uniform vec4 eau_claire : source_color = vec4(0.27, 0.74, 0.98, 1.0);   // celle d'eau.gdshader
uniform vec4 lisere : source_color = vec4(0.70, 0.93, 1.0, 1.0);
uniform vec4 eau_fonce : source_color = vec4(0.10, 0.40, 0.85, 1.0);    // celle d'eau.gdshader
uniform float profondeur_fonce = 3.0;

void fragment() {
	float travers = abs(UV.y);
	float l = UV.x;
	vec4 c = mix(coeur, bord, smoothstep(0.35, 1.0, travers));
	// des stries qui descendent : leur phase avance avec le temps, et plus vite plus bas
	float s = sin(l * 11.0 - TIME * (9.0 + 6.0 * l) + UV.y * 2.5) * sin(l * 4.3 - TIME * 5.0 - UV.y * 1.7);
	c = mix(c, strie, smoothstep(0.55, 0.95, s) * 0.6);
	float bords_doux = 1.0 - smoothstep(0.75, 1.0, travers);
	float a = COLOR.a * bords_doux;
	// au départ d'une lèvre : la couleur de l'eau, opaque, liseré en haut
	float depart = COLOR.r * (1.0 - smoothstep(0.08, 0.4, l));
	vec4 eau = mix(eau_claire, eau_fonce, smoothstep(0.0, profondeur_fonce, COLOR.b * 8.0));
	eau = mix(eau, lisere, smoothstep(-0.55, -0.8, UV.y));
	c = mix(c, eau, depart);
	a = mix(a, 1.0, depart);
	// un filet presque tari (COLOR.g) s'égrène en gouttes qui tombent, au lieu
	// de rester un fil continu : sauf tout au départ, où il tient au bord
	float gouttes = step(fract(l * 4.5 - TIME * 6.0), 0.45);
	a *= mix(1.0, gouttes, COLOR.g * smoothstep(0.08, 0.25, l));
	COLOR = vec4(c.rgb, a);
}
