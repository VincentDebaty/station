#!/bin/bash
# ------------------------------------------------------------------
# Poser ÉCLUSES sur un téléphone Android branché — export, installation,
# lancement (lot 0, 13 octobre 2026 : mesurer la vitesse du jeu sur le
# Samsung Galaxy A12 de Vincent, un vrai téléphone d'entrée de gamme).
#
#     tools/android-ecluses.sh                   exporte, installe et lance
#     tools/android-ecluses.sh --demo 1-4        … et joue la démo du 1-4,
#                                                puis imprime les images/s
#
# Le préréglage « Android » vit dans prototypes/ecluses-godot/export_presets.cfg
# (ignoré par git, comme celui d'iOS). Il signe avec la clé de débogage de
# Godot ; la clé de publication viendra avec le compte Google Play.
#
# Sur un téléphone, on ne peut pas poser de variables d'environnement : la
# démo les lit dans user://env.cfg, que ce script écrit par `adb run-as`
# (seulement sur une version de débogage) et efface ensuite.
# ------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."
PROJET_GODOT="$PWD/prototypes/ecluses-godot"
APK="$HOME/Library/Caches/Ecluses-android/ecluses.apk"
PAQUET=be.vincentdebaty.ecluses
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }

if [ "$("$ADB" devices | awk 'NR==2{print $2}')" != "device" ]; then
  rouge "aucun Android autorisé : le brancher, le déverrouiller et accepter le débogage USB"
  exit 1
fi

echo "→ export de l'APK…"
mkdir -p "$(dirname "$APK")"
godot --headless --path "$PROJET_GODOT" --export-debug "Android" "$APK" > /tmp/ecluses-android-export.log 2>&1
if [ ! -f "$APK" ] || grep -q "^ERROR: Project export" /tmp/ecluses-android-export.log; then
  rouge "export raté — voir /tmp/ecluses-android-export.log"
  exit 1
fi
# l'export de Godot relance le serveur adb : le téléphone y repasse
# « unauthorized » une à deux secondes, le temps de reconnaître la clé
attendre_appareil() {
  for _ in $(seq 1 20); do
    [ "$("$ADB" devices | awk 'NR==2{print $2}')" = "device" ] && return 0
    sleep 1
  done
  rouge "l'Android ne répond plus : le déverrouiller et vérifier le débogage USB"
  exit 1
}
attendre_appareil
echo "→ installation…"
"$ADB" install -r "$APK" > /dev/null || exit 1

if [ "${1:-}" = "--demo" ]; then
  NIVEAU="${2:-1-4}"
  printf 'ECLUSES_DEMO=1\nECLUSES_NIVEAU=%s\n%s\n' "$NIVEAU" "${ECLUSES_EN_PLUS:-}" | "$ADB" shell "run-as $PAQUET sh -c 'mkdir -p files && cat > files/env.cfg'"
  "$ADB" logcat -c
  "$ADB" shell am start -n "$PAQUET/com.godot.game.GodotAppLauncher" > /dev/null
  echo "→ démo du $NIVEAU…"
  # la démo imprime « IPS … » chaque seconde, puis « IPS FIN … »
  for _ in $(seq 1 120); do
    sleep 1
    if "$ADB" logcat -d -s godot:I | grep -q "IPS FIN"; then break; fi
  done
  "$ADB" logcat -d -s godot:I | grep -E "IPS|CHRONO" | sed -E "s/.*(IPS|CHRONO)/\1/"
  "$ADB" shell "run-as $PAQUET rm -f files/env.cfg"
  "$ADB" shell am force-stop "$PAQUET"
  exit 0
fi

"$ADB" shell am start -n "$PAQUET/com.godot.game.GodotAppLauncher" > /dev/null
vert "posé sur l'Android."
