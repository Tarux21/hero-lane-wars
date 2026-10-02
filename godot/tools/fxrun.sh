# usage: fxrun.sh name rank [hero]
G="C:/Users/kipps/Desktop/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
OUT="C:/Users/kipps/AppData/Local/Temp/fx_$1_$2"
"$G" --path godot --resolution 1280x720 -- --hero=caster --team=1 --fxtest=$1 --rank=$2 --shot=$OUT 2>&1 | grep -E "SCRIPT ERROR|Parse Error|FXTEST|ERROR: [^PR1-9]|   \[0\]|   \[1\]" | head -20
