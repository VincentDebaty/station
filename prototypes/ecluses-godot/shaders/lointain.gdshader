// Le panorama derrière le canal, mis en retrait (lot 8 de PLAN-RENDU.md :
// l'arrière-plan « concurrence parfois le puzzle »). Un peu moins saturé,
// un peu moins contrasté, et une brume bleutée qui monte vers les montagnes,
// en haut de l'image. Les éléments jouables ressortent sans devenir criards.
shader_type canvas_item;

uniform float desature = 0.28;   // 0,18 puis 0,28 (seconde analyse : le décor attirait encore l'œil)
uniform float contraste = 0.78;
uniform vec3 brume : source_color = vec3(0.80, 0.89, 0.97);
uniform float brume_haut = 0.48;    // force de la brume en haut de l'image
uniform float brume_bas = 0.12;     // et en bas, sur la prairie

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.rgb;
	float l = dot(c, vec3(0.30, 0.59, 0.11));
	c = mix(vec3(l), c, 1.0 - desature);
	c = mix(vec3(0.55), c, contraste);
	c = mix(c, brume, mix(brume_haut, brume_bas, smoothstep(0.0, 0.85, UV.y)));
	COLOR = vec4(c, t.a);
}
