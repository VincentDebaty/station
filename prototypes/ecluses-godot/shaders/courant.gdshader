// L'eau dans un aqueduc, vue en coupe. UV.x suit le conduit (0 à 1 sur toute
// sa longueur), UV.y le traverse. Des nappes plus claires et plus sombres
// glissent dans le sens du courant, quelques bulles sont entraînées, et le
// conduit est ombré comme un tuyau rond. À l'arrêt, l'eau reste calme.
// (Remplace des tirets blancs que Vincent trouvait artificiels, 6 octobre 2026.)
shader_type canvas_item;

uniform float longueur = 400.0;   // longueur du conduit, en pixels
uniform float debit = 0.0;        // 0 à l'arrêt, 1 au plus fort
uniform float sens = 1.0;         // 1 : l'eau va dans le sens du tracé
uniform float contraste = 0.35;   // réglage : à quel point les reflets ressortent
uniform float allure = 0.6;       // réglage : facteur de vitesse
uniform float phase = 0.0;        // le chemin parcouru par le motif, en pixels

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float x = UV.x * longueur;                      // en pixels le long du conduit
	float v = UV.y;
	// La position du motif, « phase », est cumulée par aqueduc.gd image après
	// image, à sens × (4 + 38 × débit) × allure pixels par seconde (158 au
	// plus fort était bien trop vif, Vincent). Écrite TIME × vitesse, elle
	// reculait dès que la vitesse baissait : le flux semblait repartir vers la
	// source à la fin d'un coup de pompe (Vincent). Le sens est réglé dans
	// aqueduc.gd, mesuré sur film.
	float u = (x + phase) / 34.0;
	// des nappes étirées dans le sens du courant
	float n = bruit(vec2(u, v * 2.5)) * 0.6 + bruit(vec2(u * 2.3 + 7.0, v * 5.0)) * 0.4;
	// moins cyan, tirant sur l'ardoise : les tuyaux paraissaient plus
	// « techniques » que la pierre et le bois (lot 7 de PLAN-RENDU.md)
	vec3 sombre = vec3(0.08, 0.27, 0.38);
	vec3 clair = vec3(0.38, 0.60, 0.70);
	vec3 moyen = mix(sombre, clair, 0.45);
	vec3 c = mix(moyen, mix(sombre, clair, smoothstep(0.3, 0.9, n)), contraste * (0.35 + 0.65 * debit));
	// des bulles entraînées, d'autant plus nombreuses que le débit est fort
	vec2 cel = vec2(floor(u * 1.6), floor(v * 3.0));
	vec2 f = vec2(fract(u * 1.6), fract(v * 3.0));
	vec2 centre = vec2(hash(cel), 0.3 + 0.4 * hash(cel + 3.7));
	float bulle = 1.0 - smoothstep(0.06, 0.11, length((f - centre) * vec2(1.0, 0.5)));
	c = mix(c, vec3(0.88, 0.98, 1.0), bulle * step(hash(cel + 9.1), 0.18 + 0.4 * debit) * debit * contraste);
	// l'ombrage d'un tuyau rond : plus sombre sur les bords
	c *= 0.62 + 0.45 * sin(v * 3.14159);
	COLOR = vec4(c, 1.0);
}
