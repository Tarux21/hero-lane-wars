@echo off
rem Öffnet das Godot-Projekt im Editor (zum Ansehen der Szenen, Modelle und Einstellungen).
set GODOT=C:\Users\kipps\Desktop\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT%" --editor --path "%~dp0godot"
