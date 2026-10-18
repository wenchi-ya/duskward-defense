@echo off
setlocal
if not exist "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" (
    echo Godot engine not found. Please open project.godot with Godot 4.7.2.
    pause
    exit /b 1
)
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
endlocal
