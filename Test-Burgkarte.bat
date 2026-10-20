@echo off
rem Test: neue Burgkarte (Entwurf)
set GODOT=C:\Users\kipps\Desktop\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT%" --path "%~dp0godot" -- --map=burg
