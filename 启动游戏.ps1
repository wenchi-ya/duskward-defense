$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$enginePath = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    Write-Host '未找到项目内的 Godot。请用 Godot 4.7.2 标准版导入本目录 project.godot，然后按 F6/F5 运行。'
    exit 1
}
Start-Process -FilePath $enginePath -ArgumentList @('--path', ('"' + $projectRoot + '"')) -WorkingDirectory $projectRoot -WindowStyle Normal
