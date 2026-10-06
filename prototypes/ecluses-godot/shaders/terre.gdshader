// La terre en coupe, d'après la maquette du niveau 14 (Vincent, 6 octobre
// 2026 : « quelque chose de plus beau pour la terre ») : un brun chaud peint
// par TACHES — des plaques sombres et des plaques d'ocre aux bords doux,
// déformées pour ne rien avoir de régulier —, des coups de pinceau couchés,
// des grains, du gravier, et de rares gros cailloux en volume (lumière en haut
// à gauche, cerne foncé, ombre portée dans la terre en bas à droite). La teinte
// s'assombrit en descendant.
shader_type canvas_item;

uniform vec3 brun : source_color = vec3(0.53, 0.32, 0.18);
uniform vec3 sombre : source_color = vec3(0.41, 0.24, 0.13);
uniform vec3 ocre : source_color = vec3(0.69, 0.47, 0.27);
uniform vec3 caillou : source_color = vec3(0.63, 0.56, 0.49);
uniform float sol_y = 0.0;   // le haut de la terre, en y monde
// la terre peinte (art/terre.png, voir peint.gd), quand elle existe : elle
// remplace taches, grains et cailloux ; les rochers sont alors des images
// semées par canal.gd
uniform bool avec_image = false;
uniform sampler2D image : source_color, repeat_enable, filter_linear_mipmap;
uniform float tuile = 512.0;

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
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * bruit(p); p *= 2.03; a *= 0.5; }
	return s;
}

// Un caillou dans une grille : renvoie (couleur, couverture). Les cailloux sont
// des sphères aplaties au contour un peu cabossé ; « ombre » est l'ombre portée
// dans la terre.
vec4 cailloux(vec2 p, float pas, float proba, float rmin, float rmax, float graine, inout float ombre) {
	vec2 q = p / pas;
	vec2 cel = floor(q), fq = fract(q);
	vec4 res = vec4(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 id = cel + o + graine;
			if (hash(id + 7.0) > proba) continue;
			vec2 centre = o + vec2(0.25 + 0.5 * hash(id), 0.25 + 0.5 * hash(id + 1.3));
			vec2 dv = (fq - centre) * vec2(1.0, 1.35 + 0.3 * hash(id + 3.1));
			float r = mix(rmin, rmax, hash(id + 2.7));
			float a = atan(dv.y, dv.x);
			r *= 1.0 + 0.07 * sin(a * 3.0 + hash(id) * 6.0) + 0.04 * sin(a * 5.0 + hash(id + 9.0) * 6.0);
			float d = length(dv);
			// l'ombre portée, décalée vers le bas à droite
			float dom = length(dv - vec2(0.18, 0.26) * r);
			ombre = max(ombre, (1.0 - smoothstep(r * 0.95, r * 1.25, dom)) * 0.45);
			if (d < r) {
				vec2 n2 = dv / r;
				vec3 n = vec3(n2, sqrt(max(1.0 - dot(n2, n2), 0.0)));
				float lum = clamp(dot(n, normalize(vec3(-0.45, -0.6, 0.66))), 0.0, 1.0);
				vec3 c = caillou * (0.9 + 0.2 * hash(id + 5.0));
				c = mix(c * 0.5, c * 1.0, smoothstep(0.05, 0.95, lum));
				c = mix(c, c * 1.1, smoothstep(0.85, 0.98, lum));                 // le reflet
				c = mix(c, vec3(0.30, 0.19, 0.11), smoothstep(r * 0.86, r, d));    // le cerne
				res = vec4(c, 1.0);
			}
		}
	}
	return res;
}

void fragment() {
	float profond = mix(1.0, 0.7, clamp((monde.y - sol_y) / 420.0, 0.0, 1.0));
	if (avec_image) {
		// la répétition se voyait (lot 5 de PLAN-RENDU.md) : le sol est
		// découpé en cellules ; chacune lit la tuile décalée au hasard, et
		// retournée une fois sur deux, avec un fondu étroit entre voisines.
		// Le gradient est pris sur les coordonnées continues, pour que les
		// mipmaps ne tracent pas de couture aux bords des cellules.
		vec2 p0 = monde / tuile;
		vec2 dx = dFdx(p0), dy = dFdy(p0);
		vec2 q = p0 * 1.35;
		vec2 cel = floor(q);
		vec2 f = fract(q);
		vec2 w = smoothstep(0.38, 0.62, f);
		vec3 acc = vec3(0.0);
		for (int j = 0; j <= 1; j++) {
			for (int i = 0; i <= 1; i++) {
				vec2 id = cel + vec2(float(i), float(j));
				vec2 uv = p0 + vec2(hash(id), hash(id + 3.7)) * 7.0;
				vec2 gx = dx, gy = dy;
				if (hash(id + 9.1) < 0.5) { uv.x = -uv.x; gx.x = -gx.x; gy.x = -gy.x; }
				float poids = (i == 0 ? 1.0 - w.x : w.x) * (j == 0 ? 1.0 - w.y : w.y);
				acc += textureGrad(image, uv, gx, gy).rgb * poids;
			}
		}
		// et une teinte qui varie lentement, à grande échelle
		acc *= 0.9 + 0.16 * fbm(monde / 520.0);
		COLOR = vec4(acc * profond, 1.0);
	} else {
		vec2 p = monde / 64.0;
		// les taches : un bruit déformé par un autre, seuillé doucement
		vec2 warp = vec2(fbm(p * 0.35 + 3.7), fbm(p * 0.35 + 8.1)) * 0.7;
		float ts = smoothstep(0.48, 0.7, fbm(p * 0.55 + warp));
		float to = smoothstep(0.52, 0.72, fbm(p * 0.6 - warp + vec2(5.2, 1.3)));
		vec3 c = brun;
		c = mix(c, sombre, ts * 0.7);
		c = mix(c, ocre, to * 0.45 * (1.0 - ts));
		// des coups de pinceau couchés, un peu en biais
		float coup = bruit(vec2(p.x * 1.1 + p.y * 0.5, p.y * 7.0 + fbm(p) * 2.0));
		c *= 0.93 + 0.12 * coup;
		c *= 0.95 + 0.1 * bruit(monde / 9.0);
		// des grains : quelques points plus sombres, quelques points clairs
		vec2 g = monde / 7.0;
		vec2 gc = floor(g);
		float gh = hash(gc + 0.5);
		float gd = length(fract(g) - 0.5 - (vec2(hash(gc + 2.0), hash(gc + 3.0)) - 0.5) * 0.4);
		if (gh < 0.05 && gd < 0.22) c *= 0.7;
		else if (gh > 0.965 && gd < 0.2) c = mix(c, ocre * 1.25, 0.6);
		// le gravier, puis les gros cailloux, chacun avec son ombre
		float ombre = 0.0;
		vec4 graviers = cailloux(p, 0.6, 0.07, 0.07, 0.13, 11.0, ombre);
		float ombre2 = 0.0;
		vec4 gros = cailloux(p, 2.8, 0.2, 0.13, 0.2, 0.0, ombre2);
		c *= 1.0 - max(ombre, ombre2);
		if (graviers.a > 0.0) c = graviers.rgb;
		if (gros.a > 0.0) c = gros.rgb;
		c *= profond;
		COLOR = vec4(c, 1.0);
	}
}
