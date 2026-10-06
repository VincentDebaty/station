extends Node
# ------------------------------------------------------------------
# LES RÉGLAGES DU RENDU DE L'EAU — à essayer au doigt, sur l'iPhone.
#
# Vincent trouvait le courant de l'aqueduc et les remous des bateaux trop
# marqués, et a proposé des curseurs pour chercher le bon dosage lui-même
# (6 octobre 2026). Le panneau « Réglages » (principal.gd) les montre, chaque
# changement s'applique tout de suite et se garde d'un lancement à l'autre
# (user://reglages.json — le téléphone, pas le dépôt). Quand les bons chiffres
# sont trouvés, ils deviennent les DEFAUTS ci-dessous.
#
# Défauts choisis par Vincent sur son iPhone le 6 octobre 2026 : un courant à
# peine visible et lent, peu de sillage, une surface qui se calme vite. Deux
# de ses valeurs touchaient la borne de leur curseur (vitesse au minimum,
# amortissement au maximum) : les bornes ont été élargies pour qu'il puisse
# aller plus loin s'il le veut. Le bouton « Réglages » reste, à sa demande.
#
# Second réglage, le même jour, sur l'eau plus profonde des lots 1 et 2 de
# PLAN-RENDU.md : un courant bien plus contrasté dans l'aqueduc (0,75, toujours
# lent), un peu moins de sillage, un peu plus de bouillon, et une surface qui
# ondule plus longtemps (amortissement 0,08).
#
# Ce sont des dosages du RENDU : aucun ne touche au moteur ni aux niveaux.
# ------------------------------------------------------------------

signal change

const FICHIER := "user://reglages.json"

# clé : [nom affiché, défaut, minimum, maximum, pas]
const CURSEURS := {
	"courant_contraste": ["Aqueduc : contraste", 0.75, 0.0, 1.0, 0.05],
	"courant_vitesse": ["Aqueduc : vitesse", 0.10, 0.0, 2.0, 0.05],
	"sillage": ["Sillage des bateaux", 0.15, 0.0, 1.5, 0.05],
	"bouillon": ["Bouillon à la sortie", 0.30, 0.0, 1.5, 0.05],
	"houle": ["Houle", 0.90, 0.0, 2.0, 0.05],
	"amortissement": ["Amortissement", 0.08, 0.02, 0.4, 0.01],
}

var valeurs := {}

func _ready() -> void:
	for k in CURSEURS: valeurs[k] = CURSEURS[k][1]
	if FileAccess.file_exists(FICHIER):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		if d is Dictionary:
			for k in d:
				if valeurs.has(k): valeurs[k] = float(d[k])

func v(cle: String) -> float:
	return valeurs.get(cle, CURSEURS[cle][1])

func regler(cle: String, x: float) -> void:
	valeurs[cle] = x
	_enregistrer()
	change.emit()

func remettre() -> void:
	for k in CURSEURS: valeurs[k] = CURSEURS[k][1]
	_enregistrer()
	change.emit()

func _enregistrer() -> void:
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(valeurs, "  "))
