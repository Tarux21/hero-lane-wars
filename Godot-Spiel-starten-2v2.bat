@echo off
rem Godot-Version im 2-gegen-2-Layout: eine breite Lane pro Team (zum Ansehen der Karte).
set GODOT=C:\Users\kipps\Desktop\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT%" --path "%~dp0godot" -- --team=2
