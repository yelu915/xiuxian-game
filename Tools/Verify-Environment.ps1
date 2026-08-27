$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$expectedUnityVersion = '6000.3.22f1'
$unityExe = Join-Path $env:LOCALAPPDATA "Unity\Editors\$expectedUnityVersion\Editor\Unity.exe"
$codeCmd = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'

$checks = [ordered]@{
    'Unity Editor' = Test-Path -LiteralPath $unityExe
    'VS Code' = Test-Path -LiteralPath $codeCmd
    'Git' = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    'Git LFS' = $null -ne (& git lfs version 2>$null)
    'Project version lock' = (Get-Content -LiteralPath (Join-Path $projectRoot 'ProjectSettings\ProjectVersion.txt') -Raw) -match [regex]::Escape($expectedUnityVersion)
    'URP package' = (Get-Content -LiteralPath (Join-Path $projectRoot 'Packages\manifest.json') -Raw) -match 'com\.unity\.render-pipelines\.universal'
    'Cinemachine package' = (Get-Content -LiteralPath (Join-Path $projectRoot 'Packages\manifest.json') -Raw) -match 'com\.unity\.cinemachine'
}

$checks.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value) { 'OK' } else { 'MISSING' }
    Write-Output ("{0,-24} {1}" -f $_.Key, $status)
}

if ($checks.Values -contains $false) {
    exit 1
}
