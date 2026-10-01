@echo off
rem Startet die Godot-Version von Hero Lane Wars (Spiel direkt, ohne Editor).
rem Falls Godot woanders liegt: Pfad in der nächsten Zeile anpassen.
set GODOT=C:\Users\kipps\Desktop\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT%" --path "%~dp0godot"
