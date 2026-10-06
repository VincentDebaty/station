#!/bin/bash
# ------------------------------------------------------------------
# Poser la tranche Godot d'ÉCLUSES sur l'iPhone — export, signature,
# installation, lancement.
#
#     tools/ios-ecluses.sh              exporte, installe et lance
#     tools/ios-ecluses.sh --export     exporte et signe seulement
#     tools/ios-ecluses.sh --etat       dit ce qui manque, sans rien faire
#
# C'est le petit frère de tools/ios.sh (Station 7), qu'on n'a pas touché :
# même compte, même équipe, même gabarit Godot 4.7.2, mêmes pièges — leurs
# explications détaillées sont là-bas. Ce qui change : le projet
# (prototypes/ecluses-godot), l'identifiant (be.vincentdebaty.ecluses), et la
# sortie (~/Library/Caches/Ecluses-ios).
#
# Le préréglage d'export, prototypes/ecluses-godot/export_presets.cfg, est
# IGNORÉ PAR GIT comme celui de Station : il porte l'équipe Apple et les
# identités de signature de cette machine. Il a été dérivé du préréglage de
# Station le 6 octobre 2026 (seuls changent export_path et
# bundle_identifier) ; sur une autre machine, le refaire de la même façon.
# ------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."
RACINE="$PWD"
PROJET_GODOT="$RACINE/prototypes/ecluses-godot"
SORTIE="$HOME/Library/Caches/Ecluses-ios"
PROJET="$SORTIE/Ecluses.xcodeproj"
BUNDLE=$(grep -E '^application/bundle_identifier' "$PROJET_GODOT/export_presets.cfg" 2>/dev/null | cut -d'"' -f2)
JOURNAL=/tmp/ecluses-ios-export.log

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }

if [ -z "${BUNDLE}" ]; then
  rouge "pas de préréglage d'export : prototypes/ecluses-godot/export_presets.cfg (voir l'en-tête)"
  exit 1
fi

# Un iPhone AU BOUT D'UN FIL (pas l'Apple Watch jointe par le réseau), lu en
# JSON (le tableau de devicectl se découpe mal) — cf. tools/ios.sh.
appareil() {
  xcrun devicectl list devices --json-output /tmp/ecluses-ios-dev.json >/dev/null 2>&1
  python3 -c "
import json
try:
    d = json.load(open('/tmp/ecluses-ios-dev.json'))
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

if [ "${1:-}" = "--etat" ]; then
  echo "identifiant   : ${BUNDLE}"
  n_comptes=$(defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null | grep -c "identifier = ")
  if [ "${n_comptes:-0}" -gt 0 ]; then vert "compte Xcode  : présent"; else rouge "compte Xcode  : AUCUN — Xcode → Réglages → Comptes"; fi
  ID=$(appareil)
  if [ -n "${ID}" ]; then vert "iPhone        : branché (${ID})"; else rouge "iPhone        : AUCUN — le brancher et le déverrouiller"; fi
  [ -d "$PROJET" ] && echo "dernier export : $(stat -f '%Sm' "$PROJET")" || echo "dernier export : aucun"
  exit 0
fi

# --- l'export : Godot pose le projet Xcode, le compile et le signe ----------
# « error: » ou « ERROR: », jamais « error » tout court (ibtool écrit
# `--errors` dans sa ligne de commande : un export réussi passait pour un
# échec — tools/ios.sh, 3 septembre 2026).
echo "→ export du projet Xcode…"
mkdir -p "$SORTIE"
godot --headless --path "$PROJET_GODOT" --import > /dev/null 2>&1
godot --headless --path "$PROJET_GODOT" --export-debug "iOS" "$PROJET" > "$JOURNAL" 2>&1
if grep -qE "error:|^ERROR:|BUILD FAILED" "$JOURNAL"; then
  rouge "  l'export a rendu une erreur :"
  grep -E "error:|^ERROR:|BUILD FAILED" "$JOURNAL" | head -6 | sed 's/^/    /'
  # Un identifiant neuf demande un profil neuf. Godot lance xcodebuild sans
  # -allowProvisioningDeviceRegistration : avec un iPhone branché, on refait
  # la compilation avec, ce qui crée le profil (remède du 20 septembre 2026).
  ID=$(appareil)
  if grep -qiE "profile|provision|no devices" "$JOURNAL" && [ -n "${ID}" ]; then
    echo "→ création du profil pour ${BUNDLE}, avec l'iPhone ${ID}…"
    ( cd "$SORTIE" && xcodebuild -project Ecluses.xcodeproj -scheme Ecluses -destination "id=${ID}" \
        -allowProvisioningUpdates -allowProvisioningDeviceRegistration build ) > /tmp/ecluses-ios-profil.log 2>&1 \
      && vert "  profil créé — relancer ce script" \
      || { rouge "  échec, voir /tmp/ecluses-ios-profil.log"; grep -E "error:" /tmp/ecluses-ios-profil.log | head -4 | sed 's/^/    /'; }
  else
    echo "  Si elle parle de profil : brancher l'iPhone et relancer (le profil se crée alors)."
    echo "  Journal complet : $JOURNAL"
  fi
  exit 1
fi
vert "  projet exporté et signé"
[ "${1:-}" = "--export" ] && exit 0

# --- l'installation, puis le lancement -------------------------------------
# L'application de l'APPAREIL est celle de l'archive (cf. tools/ios.sh, 9 septembre 2026).
APP=$(find "$SORTIE/Ecluses.xcarchive" -name "*.app" -maxdepth 4 2>/dev/null | head -1)
[ -n "${APP}" ] || APP=$(find "$SORTIE" -name "*.app" -maxdepth 5 2>/dev/null | head -1)
if [ -z "${APP}" ]; then
  rouge "aucune application produite — voir $JOURNAL"
  exit 1
fi
ID=$(appareil)
if [ -z "${ID}" ]; then
  rouge "aucun iPhone branché : l'export est prêt, il ne reste qu'à installer"
  exit 1
fi
echo "→ installation sur ${ID}…"
xcrun devicectl device install app --device "${ID}" "${APP}" || exit 1
echo "→ lancement…"
xcrun devicectl device process launch --device "${ID}" "${BUNDLE}"
vert "posé sur l'iPhone. Le compteur d'images par seconde s'affiche en ouvrant Réglages (l'engrenage)."
