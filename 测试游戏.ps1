$ErrorActionPreference = 'Stop'
$enginePath = Join-Path $PSScriptRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Godot 4.7.2 engine not found.' }
$suites = @('test_battle', 'test_save', 'test_ui_flow', 'test_rally', 'test_animation_timing', 'test_playthrough', 'test_campaign', 'test_visual_assets', 'test_campaign_ui', 'test_audio')
foreach ($suite in $suites) {
    $logPath = Join-Path $PSScriptRoot ('tools/' + $suite + '-latest.log')
    & $enginePath --headless --path $PSScriptRoot --script ('res://tests/' + $suite + '.gd') --audio-driver Dummy --log-file $logPath
    if ($LASTEXITCODE -ne 0) { throw ('Failed: ' + $suite) }
}
Write-Host 'All ten suites passed.'
