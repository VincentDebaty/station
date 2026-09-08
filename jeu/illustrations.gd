extends RefCounted
## LES ILLUSTRATIONS — une bannière par zone, une vignette par gare.
##
## Les images vivent dans `jeu/illustrations/`, dérivées de `assets/da/` par
## `tools/illustrations.sh`. Elles sont chargées à la demande et gardées en
## mémoire : dix images de cinq mégaoctets en tout, rien qui mérite un soin
## particulier.
##
## IL N'Y A PAS 277 VIGNETTES, IL Y EN A SIX. Une illustration par gare serait
## une œuvre en soi, et le jeu n'en a pas besoin : ce qu'une vignette dit,
## c'est le CARACTÈRE d'un lieu — un viaduc de montagne, une cathédrale de
## brique, une halle d'usine, un quai de port, une halte de campagne, une gare
## monumentale. Six archétypes couvrent le catalogue, et la fiche décide
## elle-même lequel lui revient.

const DOSSIER := "res://jeu/illustrations/"
static var _cache: Dictionary = {}

## LES MOTS QUI DÉSIGNENT UN LIEU. Les phrases des fiches sont écrites à la
## main, une par une, et elles disent presque toujours ce qu'est la gare :
## « au pied de la citadelle », « la gare gothique de l'acier », « le port ».
## On les lit donc plutôt que d'inventer un champ de plus dans 401 fiches —
## la donnée existe déjà, il suffisait de s'en servir.
const MOTS := {
	"port": ["port", "mer ", "maritime", "océan", "ocean", "rade", "littoral",
		"embarcadère", "digue", "ferry", "quai maritime", "estuaire", "marée"],
	"viaduc": ["viaduc", "pont", "vallée", "vallee", "gorge", "tunnel", "col ",
		"montagne", "alpin", "alpes", "sommet", "torrent"],
	"industrielle": ["acier", "charbon", "usine", "industri", "mine", "sidérurg",
		"houill", "forge", "manufacture", "textile", "fonderie", "chantier"],
	"cathedrale": ["cathédrale", "cathedrale", "gothique", "abbaye", "basilique",
		"cloître", "évêché", "collégiale"],
}


## L'archétype d'une gare : ce que sa phrase dit d'elle, et à défaut sa taille.
## La taille seule reste un bon juge — une gare de huit quais est monumentale,
## une gare de trois quais est une halte, et c'est vrai partout.
static func archetype(cfg: Dictionary) -> String:
	var texte := (String(cfg.get("tagline", "")) + " " + String(cfg.get("name", "")) \
		+ " " + String(cfg.get("desc", ""))).to_lower()
	for quoi in MOTS:
		for mot in MOTS[quoi]:
			if texte.contains(mot):
				return quoi
	var quais: int = Array(cfg.get("platforms", [])).size()
	if quais >= 8:
		return "monumentale"
	if quais >= 6:
		return "cathedrale"
	if quais >= 4:
		return "industrielle"
	return "halte"


## La vignette d'une gare, ou null si les images ne sont pas là — le jeu
## s'affiche alors exactement comme avant, sans trou.
static func vignette(cfg: Dictionary) -> Texture2D:
	return _charger("gare-" + archetype(cfg))


## LA BANDE UTILE D'UNE BANNIÈRE. Le sujet d'un paysage 3:2 — l'horizon, ce
## qui se découpe dessus — vit dans le TIERS SUPÉRIEUR, pas au milieu
## géométrique : le bas n'est que du premier plan. On découpe donc de 8 % à
## 52 % de la hauteur, ce qui garde le ciel, la ligne d'horizon et ce qui s'y
## dresse — le phare, le viaduc, la verrière — et laisse les rochers dehors.
const BANDE_HAUT := 0.08
const BANDE_BAS := 0.52


## DES ZONES QUI EMPRUNTENT LEUR PAYSAGE. Une deuxième carte nomme ses zones
## comme elle veut — « aller », « retour » — et il serait absurde de peindre un
## paysage de plus pour chacune : le grand tour du Rhin traverse les mêmes
## terres que les zones d'Europe qui portent déjà leur bannière.
const ZONES_EMPRUNTEES := {"aller": "rhin", "retour": "ger"}


## La bannière d'une zone de la carte (`atl`, `alpes`, `rhin`, `ger`).
static func banniere(zone: Variant) -> Texture2D:
	var z := String(zone)
	var nom := "banniere-" + String(ZONES_EMPRUNTEES.get(z, z))
	if _cache.has(nom + "|bande"):
		return _cache[nom + "|bande"]
	var t := _charger(nom)
	var bande: Texture2D = null
	if t != null:
		var a := AtlasTexture.new()
		a.atlas = t
		var h := t.get_height()
		a.region = Rect2(0, h * BANDE_HAUT, t.get_width(), h * (BANDE_BAS - BANDE_HAUT))
		bande = a
	_cache[nom + "|bande"] = bande
	return bande


## L'ILLUSTRATION ENTIÈRE, sans sa bande découpée. Le ruban la dessine
## lui-même — en polygone, pour lui donner des coins ronds — et recadre donc
## la bande par ses UV : une AtlasTexture ne lui servirait à rien, et
## l'empêcherait même de connaître la taille de l'image d'origine.
static func banniere_brute(zone: Variant) -> Texture2D:
	var z := String(zone)
	return _charger("banniere-" + String(ZONES_EMPRUNTEES.get(z, z)))


static func _charger(nom: String) -> Texture2D:
	if _cache.has(nom):
		return _cache[nom]
	var chemin := DOSSIER + nom + ".png"
	var t: Texture2D = load(chemin) if ResourceLoader.exists(chemin) else null
	_cache[nom] = t
	return t
