#!/bin/bash
# ------------------------------------------------------------------
# Poser le jeu sur l'iPhone — export, signature, installation, lancement.
#
#     tools/ios.sh              exporte, installe et lance
#     tools/ios.sh --export     exporte seulement (projet Xcode)
#     tools/ios.sh --etat       dit ce qui manque, sans rien faire
#
# CE QUE CE SCRIPT NE PEUT PAS FAIRE, et c'est la seule chose : ajouter un
# compte Apple à Xcode. Il faut un mot de passe et une double authentification,
# donc une main humaine, une fois pour toutes :
#
#     Xcode → Réglages → Comptes → + → Apple ID
#
# Un compte GRATUIT suffit pour son propre téléphone ; l'app expire alors au
# bout de sept jours et se réinstalle en relançant ce script. Un compte payant
# la garde un an.
#
# Ensuite, la première fois seulement, ouvrir build/ios/Station.xcodeproj,
# onglet « Signing & Capabilities », cocher « Automatically manage signing » et
# choisir l'équipe : Xcode crée le profil et enregistre l'appareil. Après quoi
# ce script se débrouille seul.
# ------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."
RACINE="$PWD"
# LA FABRICATION SORT DU DÉPÔT. Exporté dans le projet, Godot se prend les
# pieds dans ses propres fichiers : il relit les icônes qu'il vient d'écrire
# par un chemin `res://build/...` que son système de fichiers ne connaît pas
# encore, et l'export échoue (mesuré le 3 septembre 2026). Le cache de macOS
# est l'endroit prévu pour ça.
SORTIE="$HOME/Library/Caches/Station-ios"
PROJET="$SORTIE/Station.xcodeproj"
BUNDLE=$(grep -E '^application/bundle_identifier' export_presets.cfg 2>/dev/null | cut -d'"' -f2)
EQUIPE=$(grep -E '^application/app_store_team_id' export_presets.cfg 2>/dev/null | cut -d'"' -f2)

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }

# --- ce qui est en place ---------------------------------------------------
etat() {
  echo "identifiant   : ${BUNDLE:-(aucun)}"
  echo "équipe        : ${EQUIPE:-(aucune)}"
  local n_comptes
  n_comptes=$(defaults read com.apple.dt.Xcode IDEProvisioningTeams 2>/dev/null | grep -c teamID)
  if [ "${n_comptes:-0}" -gt 0 ]; then
    vert "compte Xcode  : présent"
  else
    rouge "compte Xcode  : AUCUN — Xcode → Réglages → Comptes → + → Apple ID"
  fi
  local prof
  prof=$(ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | wc -l | tr -d ' ')
  echo "profils        : ${prof}"
  local dev
  dev=$(xcrun devicectl list devices 2>/dev/null | grep -c "connected")
  if [ "${dev:-0}" -gt 0 ]; then
    vert "appareil       : connecté"
    xcrun devicectl list devices 2>/dev/null | grep "connected" | sed 's/^/                 /'
  else
    rouge "appareil       : AUCUN — brancher l'iPhone et le déverrouiller"
  fi
}

if [ "${1:-}" = "--etat" ]; then etat; exit 0; fi

# --- l'export : Godot pose le projet Xcode, le compile et le signe ----------
echo "→ export du projet Xcode…"
mkdir -p "$SORTIE"
# « error » TOUT COURT NE MARCHE PAS : la ligne de commande d'ibtool contient
# `--errors --warnings --notices`, et l'export réussi passait pour un échec
# (mesuré le 3 septembre 2026). On cherche donc « error: » ou « ERROR: ».
godot --headless --path . --export-debug "iOS" "$PROJET" > /tmp/station-ios-export.log 2>&1
if ! grep -qE "error:|^ERROR:|BUILD FAILED" /tmp/station-ios-export.log; then
  vert "  projet exporté et signé"
else
  rouge "  l'export a rendu une erreur :"
  grep -E "error:|^ERROR:|BUILD FAILED" /tmp/station-ios-export.log | head -5 | sed 's/^/    /'
  echo
  echo "  Si elle parle de compte ou de profil, c'est l'étape humaine :"
  echo "  Xcode → Réglages → Comptes, puis ouvrir $PROJET une fois."
  exit 1
fi
[ "${1:-}" = "--export" ] && exit 0

# --- l'installation, puis le lancement -------------------------------------
APP=$(find "$SORTIE" -name "Station.app" -maxdepth 5 2>/dev/null | head -1)
if [ -z "$APP" ]; then
  rouge "aucune Station.app produite — voir /tmp/station-ios-export.log"
  exit 1
fi
# L'IDENTIFIANT SE LIT EN JSON. Découpé à la colonne dans le tableau de
# devicectl, on récoltait « 16 » (un morceau d'« iPhone 16 Pro »).
xcrun devicectl list devices --json-output /tmp/station-ios-dev.json >/dev/null 2>&1
ID=$(python3 -c "
import json
try:
    d = json.load(open('/tmp/station-ios-dev.json'))
except Exception:
    raise SystemExit
for x in d['result']['devices']:
    if x.get('connectionProperties', {}).get('pairingState') == 'paired':
        print(x['identifier'])
        break
" 2>/dev/null)
if [ -z "$ID" ]; then
  rouge "aucun appareil connecté"
  exit 1
fi
echo "→ installation sur $ID…"
xcrun devicectl device install app --device "$ID" "$APP" || exit 1
echo "→ lancement…"
xcrun devicectl device process launch --device "$ID" "$BUNDLE"
vert "posé sur l'appareil."
