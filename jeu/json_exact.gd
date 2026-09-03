class_name JsonExact
## UN JSON QUI ÉCRIT CE QUI A ÉTÉ CALCULÉ.
##
## `JSON.stringify` de Godot arrondit les flottants à six chiffres : bon pour
## un fichier de sauvegarde, inutilisable pour un oracle qui compare des
## doubles à 1e-6. Ici : flottants à 17 décimales (plus que les 16 chiffres
## utiles d'un double, donc tour complet garanti), entiers et flottants
## entiers sans point, clés dans l'ordre d'insertion, l'infini nommé.
##
## Partagé par les oracles (jeu/oracle_*.gd). Ne sert à rien dans le jeu.


static func ecrire(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			if is_inf(v):
				return "\"Infinity\"" if v > 0 else "\"-Infinity\""
			if is_nan(v):
				return "\"NaN\""
			if v == floor(v) and abs(v) < 1e15:
				return "%d" % int(v)
			return "%.17f" % v
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(v))
		TYPE_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var parts: PackedStringArray = []
			for e in v:
				parts.append(ecrire(e))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts: PackedStringArray = []
			for k in v.keys():
				parts.append(JSON.stringify(str(k)) + ":" + ecrire(v[k]))
			return "{" + ",".join(parts) + "}"
		_:
			return JSON.stringify(str(v))
