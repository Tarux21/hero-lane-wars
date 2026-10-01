@echo off
rem Godot-Version im 4-gegen-4-Layout: Doppel-Lane pro Team (zum Ansehen der Karte).
set GODOT=C:\Users\kipps\Desktop\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT%" --path "%~dp0godot" -- --team=4
