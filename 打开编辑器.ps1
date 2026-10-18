$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$enginePath = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    Write-Host '请先准备 Godot 4.7.2 标准版。'
    exit 1
}
Start-Process -FilePath $enginePath -ArgumentList @('--editor', '--path', ('"' + $projectRoot + '"')) -WorkingDirectory $projectRoot -WindowStyle Normal
