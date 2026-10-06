// Le vantail d'une porte : des planches verticales, leur fil, trois ferrures.
// « cadre » est le rectangle du vantail en y monde (haut, bas) et x monde
// (gauche, droite) ; « tranche » assombrit un vantail vu de côté (ouvert).
shader_type canvas_item;

uniform vec4 cadre = vec4(0.0, 0.0, 100.0, 100.0);   // x0, y0, x1, y1
uniform float tranche = 0.0;
uniform vec3 bois : source_color = vec3(0.55, 0.33, 0.17);
uniform vec3 fer : source_color = vec3(0.17, 0.17, 0.19);
// le vantail peint (art/vantail.png, voir peint.gd), quand il existe : posé
// sur le cadre entier, ferrures comprises, il monte avec lui
uniform bool avec_image = false;
uniform sampler2D image : source_color, filter_linear_mipmap;

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

void fragment() {
	vec2 l = (monde - cadre.xy) / max(cadre.zw - cadre.xy, vec2(1.0));   // 0..1 dans le vantail
	if (avec_image) {
		vec4 t = texture(image, clamp(l, vec2(0.0), vec2(1.0)));
		COLOR = vec4(t.rgb * mix(1.0, 0.55, tranche), t.a);
	} else {
		float largeur = cadre.z - cadre.x;
		float planches = max(2.0, floor(largeur / 13.0));
		float pl = l.x * planches;
		float idp = floor(pl);
		float fil = bruit(vec2(monde.x * 0.9 + idp * 13.0, monde.y * 0.05)) * 0.5 + bruit(vec2(monde.x * 2.7, monde.y * 0.11)) * 0.25;
		vec3 c = bois * (0.82 + 0.25 * hash(vec2(idp, 3.0))) * (0.85 + 0.3 * fil);
		float joint = min(fract(pl), 1.0 - fract(pl)) * largeur / planches;
		c *= mix(0.55, 1.0, smoothstep(0.6, 1.8, joint));
		// trois ferrures, avec leurs rivets
		float h = cadre.w - cadre.y;
		for (int i = 0; i < 3; i++) {
			float yb = cadre.y + h * (0.14 + 0.36 * float(i));
			float dy = abs(monde.y - yb);
			if (dy < 4.5) {
				c = fer * (1.1 - dy / 9.0);
				float rx = fract(l.x * planches);
				if (abs(rx - 0.5) * largeur / planches < 2.2 && dy < 2.2) c = vec3(0.42);
			}
		}
		c *= mix(1.0, 0.55, tranche);
		COLOR = vec4(c, 1.0);
	}
}
