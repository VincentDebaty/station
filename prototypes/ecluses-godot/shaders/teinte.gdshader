// Recolorie un bateau. Une seule image sert de modèle (art/bateau_0.png, le
// rouge) : ChatGPT ne sait pas recolorier une image, il la redessine, et la
// taille change à chaque fois. Ici, seul le rouge VIF change de teinte (coque,
// fanion, bande de la cheminée, bouée) ; le rouge sombre de l'antifouling,
// sous la ligne de flottaison, est trop peu lumineux pour être pris.
// Mesuré sur le modèle du 6 octobre 2026 : coque v = 0,91, antifouling v = 0,54.
shader_type canvas_item;

uniform bool actif = false;
uniform float teinte = 0.0;        // la nouvelle teinte, de 0 à 1
uniform float saturation = 1.0;    // facteurs appliqués au rouge d'origine
uniform float luminosite = 1.0;

vec3 vers_tsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 vers_rvb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = COLOR;
	if (actif) {
		vec3 t = vers_tsv(c.rgb);
		float rouge = 1.0 - smoothstep(0.035, 0.075, min(t.x, 1.0 - t.x));
		float vif = smoothstep(0.62, 0.74, t.z) * smoothstep(0.40, 0.55, t.y);
		vec3 n = vers_rvb(vec3(teinte, clamp(t.y * saturation, 0.0, 1.0), clamp(t.z * luminosite, 0.0, 1.0)));
		c.rgb = mix(c.rgb, n, rouge * vif);
	}
	COLOR = c;
}
