// Le style « dessin animé » (essai du 13 octobre 2026, d'après l'image cible
// faite par Vincent avec ChatGPT) : des couleurs plus franches et un peu plus
// claires sur tout le décor. vif = 0 : le style actuel ; 1 : le dessin animé.
// Réglé par principal.gd (Réglages → Style dessin animé).
global uniform float vif;

vec3 vivifier(vec3 c) {
	float l = dot(c, vec3(0.30, 0.59, 0.11));
	c = mix(vec3(l), c, 1.0 + 0.35 * vif);
	c *= 1.0 + 0.07 * vif;
	return clamp(c, 0.0, 1.0);
}
