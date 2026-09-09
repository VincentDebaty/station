#!/bin/bash
# ------------------------------------------------------------------
# Poser le jeu sur l'iPhone — export, signature, installation, lancement.
#
#     tools/ios.sh              exporte, installe et lance
#     tools/ios.sh --export     exporte seulement (projet Xcode)
#     tools/ios.sh --etat       dit ce qui manque, sans rien faire
#     tools/ios.sh --simulateur pose le jeu sur le simulateur iOS démarré
#
# LE SIMULATEUR A DEMANDÉ UN GABARIT RECOMPILÉ (9 septembre 2026). Celui que
# Godot 4.7.2 distribue annonce une tranche « ios-arm64_x86_64-simulator » dont
# la bibliothèque `libgodot.a` ne contient QUE x86_64 — le nom du dossier ment.
# Or ce Mac est en arm64 et tous ses simulateurs le sont : rien ne pouvait se
# lier. MoltenVK, dans le même gabarit, livre bien ses deux tranches ; c'est
# donc propre à la bibliothèque du moteur.
#
# La tranche manquante a été compilée depuis les sources :
#
#     scons platform=ios arch=arm64 ios_simulator=yes target=template_debug
#
# puis fondue à l'existante (`lipo -create`) dans
# `~/Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip`.
# Le gabarit officiel intact est gardé à côté sous
# `ios-officiel-sans-simulateur.zip`. UNE MISE À JOUR DE GODOT EFFACERA CE
# CORRECTIF : il faudra le refaire, et ces vingt lignes disent comment.
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

# L'IDENTIFIANT SE LIT EN JSON, ET LE CÂBLE PASSE D'ABORD. Deux erreurs
# corrigées ici le 3 septembre 2026 : découpé à la colonne dans le tableau de
# devicectl on récoltait « 16 » (un morceau d'« iPhone 16 Pro ») ; et la
# première entrée appairée était l'Apple Watch, jointe par le réseau local,
# dont le tunnel expirait au bout d'une minute. On veut un appareil au bout
# d'un fil, dont le tunnel est établi.
xcrun devicectl list devices --json-output /tmp/station-ios-dev.json >/dev/null 2>&1
ID=$(python3 -c "
import json
try:
    d = json.load(open('/tmp/station-ios-dev.json'))
except Exception:
    raise SystemExit
def note(x):
    p = x.get('connectionProperties', {})
    n = 0
    if p.get('transportType') == 'wired': n += 4
    if p.get('tunnelState') == 'connected': n += 2
    if 'iPhone' in x.get('deviceProperties', {}).get('name', ''): n += 1
    return n
cands = [x for x in d['result']['devices']
         if x.get('connectionProperties', {}).get('pairingState') == 'paired']
cands.sort(key=note, reverse=True)
if cands and note(cands[0]) >= 4:
    print(cands[0]['identifier'])
" 2>/dev/null)
appareil() {
  xcrun devicectl list devices --json-output /tmp/station-ios-dev.json >/dev/null 2>&1
  python3 -c "
import json
try:
    d = json.load(open('/tmp/station-ios-dev.json'))
except Exception:
    raise SystemExit
def note(x):
    p = x.get('connectionProperties', {})
    n = 0
    if p.get('transportType') == 'wired': n += 4
    if p.get('tunnelState') == 'connected': n += 2
    if 'iPhone' in x.get('deviceProperties', {}).get('name', ''): n += 1
    return n
cands = [x for x in d['result']['devices']
         if x.get('connectionProperties', {}).get('pairingState') == 'paired']
cands.sort(key=note, reverse=True)
if cands and note(cands[0]) >= 4:
    print(cands[0]['identifier'])
" 2>/dev/null
}

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

# --- récupérer la dernière capture prise sur l'appareil ---------------------
# Trois doigts posés sur l'écran du jeu enregistrent l'image ; celle-ci va la
# chercher dans le conteneur de l'app. Ni la console ni devicectl n'offrent
# de capture, et la Recopie d'iPhone n'existe pas sur ce Mac.
if [ "${1:-}" = "--capture" ]; then
  ID=$(appareil) || { rouge "aucun iPhone au bout du fil"; exit 1; }
  VERS="${2:-/tmp/station-capture.png}"
  xcrun devicectl device copy from --device "$ID" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --source Documents/capture.png --destination "$VERS" > /dev/null 2>&1 \
    && vert "capture : $VERS" || rouge "aucune capture sur l'appareil (trois doigts sur l'écran du jeu)"
  exit 0
fi

# --- le simulateur : même export, mais compilé pour le SDK du simulateur ----
# Godot ne produit pas d'application, il produit un PROJET Xcode : c'est donc
# xcodebuild qui décide de la cible, et le simulateur n'est qu'un autre SDK.
# On ne signe pas — un simulateur ne le demande pas, et c'est ce qui rend cette
# voie utilisable sans appareil ni compte.
if [ "${1:-}" = "--simulateur" ]; then
  SIM=$(xcrun simctl list devices booted | grep -Eo "[0-9A-F-]{36}" | head -1)
  if [ -z "$SIM" ]; then
    rouge "aucun simulateur démarré — ouvrir Simulator, ou : xcrun simctl boot 'iPhone 17'"
    exit 1
  fi
  echo "→ export du projet Xcode…"
  mkdir -p "$SORTIE"
  godot --headless --path . --export-debug "iOS" "$PROJET" > /tmp/station-ios-export.log 2>&1
  echo "→ compilation pour le simulateur…"
  BUILD="$(dirname "$PROJET")/build-sim"
  if ! xcodebuild -project "$PROJET" -target Station -configuration Debug       -sdk iphonesimulator -arch arm64       CONFIGURATION_BUILD_DIR="$BUILD"       CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO       build > /tmp/station-sim-build.log 2>&1; then
    rouge "  la compilation a échoué :"
    grep -E "error:" /tmp/station-sim-build.log | head -5 | sed 's/^/    /'
    exit 1
  fi
  vert "  application compilée"
  xcrun simctl install "$SIM" "$BUILD/Station.app" || exit 1
  xcrun simctl launch "$SIM" "$BUNDLE" > /dev/null || exit 1
  open -a Simulator
  vert "posé sur le simulateur — ⌘← dans la fenêtre pour la mettre en paysage."
  echo "  ⚠ le simulateur SACCADE, et ce n'est pas le jeu : il n'a pas de Vulkan,"
  echo "    Godot y retombe sur OpenGL ES 3.0 par-dessus un GPU paravirtualisé"
  echo "    (mesuré : « Setting up an OpenGL ES 3.0 context » à son lancement,"
  echo "    là où l'appareil rend en Metal, moteur « mobile »). Il vaut pour la"
  echo "    MISE EN PAGE et la zone sûre, jamais pour juger la fluidité."
  exit 0
fi

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
# L'APPLICATION DE L'APPAREIL EST CELLE DE L'ARCHIVE, ET SEULEMENT ELLE. Cette
# recherche balayait tout le dossier de sortie ; depuis que `--simulateur` y
# dépose sa propre `Station.app`, elle ramassait la build du SIMULATEUR — non
# signée, refusée par l'appareil avec « The executable contains an invalid
# signature » (mesuré le 9 septembre 2026, et le message ne dit évidemment pas
# qu'on lui a tendu la mauvaise app).
APP=$(find "$SORTIE/Station.xcarchive" -name "Station.app" -maxdepth 4 2>/dev/null | head -1)
[ -n "$APP" ] || APP=$(find "$SORTIE" -path "$SORTIE/build-sim" -prune -o -name "Station.app" -print -maxdepth 5 2>/dev/null | head -1)
if [ -z "$APP" ]; then
  rouge "aucune Station.app produite — voir /tmp/station-ios-export.log"
  exit 1
fi
ID=$(appareil)
if [ -z "$ID" ]; then
  rouge "aucun appareil connecté"
  exit 1
fi
echo "→ installation sur $ID…"
xcrun devicectl device install app --device "$ID" "$APP" || exit 1
echo "→ lancement…"
xcrun devicectl device process launch --device "$ID" "$BUNDLE"
vert "posé sur l'appareil."
