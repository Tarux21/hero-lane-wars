#!/usr/bin/env bash
# Balancing-Messung: viele Bot-gegen-Bot-Partien (Godot, ohne Fenster) parallel, je Partie eine JSON-Datei.
# Aufruf (vom Projektordner aus):  bash tools/balance/run_matrix.sh <Ausgabeordner> [Wiederholungen=12] [parallel=10]
# Optional: TUNE=pfad.json (Werte überschreiben, siehe --tune in game.gd), BLOCKS="klassen stile stufen" (nur diese Blöcke).
# Blöcke: Klassen (jede gegen jede, Normal), Bot-Stile (balanced/rush/eco gegeneinander), Schwierigkeit (Stufe gegen Stufe).
set -u
OUT="${1:?Ausgabeordner fehlt}"
REP="${2:-12}"
PAR="${3:-10}"
G="$(grep -m1 -o 'C:[^"]*Godot_v4[^"]*console\.exe' Alle-Tests.bat 2>/dev/null || echo 'C:/Users/kipps/Desktop/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')"
G="${G//\\//}"                                  # Backslashes in Schrägstriche
mkdir -p "$OUT"
CL=(tank damage caster)
JOBS="$OUT/jobs.txt"
: > "$JOBS"
BLOCKS="${BLOCKS:-klassen stile stufen}"
[[ " $BLOCKS " == *" klassen "* ]] && for h in "${CL[@]}"; do for e in "${CL[@]}"; do for s in $(seq 1 "$REP"); do
  echo "klassen_${h}_${e}_$s --hero=$h --enemy=$e --diff=normal --style=random --estyle=random --seed=$s" >> "$JOBS"
done; done; done
[[ " $BLOCKS " == *" stile "* ]] && for a in balanced rush eco; do for b in balanced rush eco; do for s in $(seq 1 "$REP"); do
  h=${CL[$((s % 3))]}; e=$h                      # gleiche Klasse auf beiden Seiten: nur der Stil soll entscheiden
  echo "stile_${a}_${b}_$s --hero=$h --enemy=$e --diff=normal --style=$a --estyle=$b --seed=$((100 + s))" >> "$JOBS"
done; done; done
[[ " $BLOCKS " == *" stufen "* ]] && for pair in "hard normal" "normal easy" "expert hard" "easy easy" "hard hard"; do set -- $pair; for s in $(seq 1 $((REP * 2))); do
  h=${CL[$((s % 3))]}; e=${CL[$(((s / 3) % 3))]}
  echo "stufen_${1}_${2}_$s --hero=$h --enemy=$e --diff=$1 --ediff=$2 --style=random --estyle=random --seed=$((200 + s))" >> "$JOBS"
done; done
echo "Partien: $(wc -l < "$JOBS")"
run_one() {
  name="$1"; shift
  "$G" --headless --path godot -- --botplay --sim=5400 --team=1 "${TUNE:+--tune=$TUNE}" "$@" "--result=$OUT/$name.json" > /dev/null 2>&1
}
export -f run_one
export G OUT TUNE
start=$(date +%s)
xargs -P "$PAR" -L 1 bash -c 'run_one "$@"' _ < "$JOBS"
echo "fertig in $(( $(date +%s) - start )) s, Dateien: $(ls "$OUT"/*.json 2>/dev/null | wc -l)"
