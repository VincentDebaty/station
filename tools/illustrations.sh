#!/bin/bash
# ------------------------------------------------------------------
# Dériver les illustrations pour le jeu.
#
#     tools/illustrations.sh
#
# Les originaux vivent dans `assets/da/` — c'est là qu'on dépose ce qui sort
# du générateur, en pleine résolution, et ce dossier porte un `.gdignore` :
# Godot ne le voit pas. Ce script en tire ce que l'application embarque,
# dans `jeu/illustrations/`.
#
# POURQUOI DEUX COPIES, alors que le projet tient à n'en avoir qu'une. Parce
# que ce ne sont pas deux copies de la même chose : l'une est la SOURCE
# (1536 × 1024, quatre mégaoctets pièce), l'autre un ARTEFACT DÉRIVÉ, taillé
# pour l'écran d'un téléphone. Les dix originaux pèsent 33 Mo ; embarqués
# tels quels ils feraient une application quatre fois plus lourde que le jeu
# lui-même, pour des images affichées à 240 pixels de haut. C'est exactement
# ce que fait déjà `tools/vers-json.mjs` avec `data/derive/`.
#
# Relancer après chaque dépôt dans `assets/da/`. Idempotent.
# ------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."
SRC="assets/da"
DST="jeu/illustrations"
mkdir -p "$DST"

vert() { printf '\033[32m%s\033[0m\n' "$1"; }
rouge() { printf '\033[31m%s\033[0m\n' "$1"; }

# LA BANNIÈRE N'EST PLUS RECADRÉE ICI. Elle l'était, et le résultat coupait
# DEUX FOIS : une bande centrée à la dérivation, puis un second rognage à
# l'affichage, le panneau étant plus large encore que la bande. Le phare de
# l'Atlantique y a disparu. Le jeu choisit désormais sa bande lui-même, par
# une AtlasTexture (jeu/illustrations.gd) : un seul recadrage, et sur la
# partie qui porte le sujet plutôt que sur le milieu géométrique.
n=0
for f in "$SRC"/banniere-*.png; do
  [ -f "$f" ] || continue
  nom=$(basename "$f")
  cp "$f" "$DST/$nom"
  sips -Z 1024 "$DST/$nom" >/dev/null 2>&1
  n=$((n + 1))
done

# LA VIGNETTE EST UN TIMBRE. Elle s'affiche dans un carré d'environ soixante
# points ; 384 pixels lui laissent de la marge sur un écran à trois fois la
# densité, et rien de plus.
m=0
for f in "$SRC"/gare-*.png; do
  [ -f "$f" ] || continue
  nom=$(basename "$f")
  cp "$f" "$DST/$nom"
  sips -Z 384 "$DST/$nom" >/dev/null 2>&1
  m=$((m + 1))
done

if [ $((n + m)) -eq 0 ]; then
  rouge "aucune image dans $SRC — voir $SRC/LISEZ-MOI.md pour les noms attendus"
  exit 1
fi
avant=$(du -sh "$SRC" | cut -f1)
apres=$(du -sh "$DST" | cut -f1)
vert "$n bannière(s) et $m vignette(s) dérivées — $avant en source, $apres embarqués"
