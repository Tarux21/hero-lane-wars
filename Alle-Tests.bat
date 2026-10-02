@echo off
rem Führt alle automatischen Prüfungen der Godot-Version aus (dauert etwa 1 Minute).
rem Jede Zeile muss am Ende "identisch" bzw. "OK" zeigen. Ergebnis steht auch in Alle-Tests-Ergebnis.txt
set GODOT=C:\Users\kipps\Desktop\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
set P=%~dp0godot
set OUT=%~dp0Alle-Tests-Ergebnis.txt
echo Hero Lane Wars - Pruefungen > "%OUT%"
echo. >> "%OUT%"
echo [1/6] Skills (205 Vergleichsszenarien mit dem Prototyp)
"%GODOT%" --headless --path "%P%" -- --golden 2>&1 | findstr /C:"GOLDEN:" /C:"FAIL" >> "%OUT%"
echo [2/6] Wirtschaft, Items, Bot (4339 Vergleichsfaelle)
"%GODOT%" --headless --path "%P%" -- --golden-eco 2>&1 | findstr /C:"GOLDEN-ECO" /C:"FAIL" >> "%OUT%"
echo [3/6] Boss und Elite (32 Szenarien)
"%GODOT%" --headless --path "%P%" -- --golden-boss 2>&1 | findstr /C:"GOLDEN-BOSS" /C:"FAIL" >> "%OUT%"
echo [4/6] Shop-Regeln
"%GODOT%" --headless --path "%P%" -- --selftest-items --team=1 2>&1 | findstr /C:"SELFTEST-ITEMS" /C:"FAIL" >> "%OUT%"
echo [5/6] Karte, Lane-Wechsel, Backport, Minimap (4 gegen 4)
"%GODOT%" --headless --path "%P%" -- --selftest --team=4 2>&1 | findstr /C:"SELFTEST" /C:"FAIL" >> "%OUT%"
echo [6/6] Ganze Partie Bot gegen Bot (1 gegen 1)
"%GODOT%" --headless --path "%P%" -- --botplay --sim=2400 --team=1 --diff=normal 2>&1 | findstr /B /C:"SIM" >> "%OUT%"
echo.
type "%OUT%"
echo.
pause
