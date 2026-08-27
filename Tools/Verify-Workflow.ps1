param(
    [switch]$Deep
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workflow.Common.ps1')

$projectRoot = Get-XianxiaProjectRoot
$settings = Get-XianxiaLocalSettings
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Name, [bool]$Passed, [string]$Level, [string]$Detail)
    $checks.Add([pscustomobject]@{ Name = $Name; Passed = $Passed; Level = $Level; Detail = $Detail })
}

$unityVersion = ((Get-Content -LiteralPath (Join-Path $projectRoot 'ProjectSettings\ProjectVersion.txt') | Select-Object -First 1) -split ':', 2)[1].Trim()
$unityExe = Join-Path $env:LOCALAPPDATA ("Unity\Editors\{0}\Editor\Unity.exe" -f $unityVersion)
Add-Check 'Unity version lock' (Test-Path -LiteralPath $unityExe) 'required' $unityVersion
Add-Check 'AGENTS.md' (Test-Path -LiteralPath (Join-Path $projectRoot 'AGENTS.md')) 'required' 'Repository AI instructions'
Add-Check 'Codex config' (Test-Path -LiteralPath (Join-Path $projectRoot '.codex\config.toml')) 'required' 'Trust the repo on each host'

$git = Get-Command git -ErrorAction SilentlyContinue
Add-Check 'Git' ($null -ne $git) 'required' $(if ($git) { $git.Source } else { 'not found' })
$lfsOkay = $false
$remoteOkay = $false
if ($git) {
    $gitSafeDirectory = "safe.directory={0}" -f $projectRoot
    $lfsOkay = $null -ne (& git -c $gitSafeDirectory -C $projectRoot lfs version 2>$null)
    $remoteNames = @(& git -c $gitSafeDirectory -C $projectRoot remote)
    if ($remoteNames -contains 'origin') {
        $remoteOkay = -not [string]::IsNullOrWhiteSpace((& git -c $gitSafeDirectory -C $projectRoot remote get-url origin))
    }
}
Add-Check 'Git LFS' $lfsOkay 'required' 'Large approved assets'
Add-Check 'Git origin' $remoteOkay 'attention' $(if ($remoteOkay) { 'configured' } else { 'remote provider not selected yet' })

$localConfig = Test-Path -LiteralPath (Join-Path $projectRoot '.env.local')
Add-Check 'Local config' $localConfig 'required' '.env.local'
$comfyRoot = Get-XianxiaSetting -Settings $settings -Name 'COMFYUI_ROOT'
$modelRoot = Get-XianxiaSetting -Settings $settings -Name 'COMFYUI_MODEL_ROOT'
$portableReady = $false
if (-not [string]::IsNullOrWhiteSpace($comfyRoot)) {
    $portableReady = (Test-Path -LiteralPath (Join-Path $comfyRoot 'ComfyUI\main.py')) -and ((Test-Path -LiteralPath (Join-Path $comfyRoot 'python_embeded\python.exe')) -or (Test-Path -LiteralPath (Join-Path $comfyRoot 'python_embedded\python.exe')))
}
Add-Check 'ComfyUI portable' $portableReady 'required' $(if ($comfyRoot) { $comfyRoot } else { 'path not configured' })

$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'AI\models.lock.json') -Raw | ConvertFrom-Json
$baseModel = $lock.models | Where-Object { $_.status -eq 'approved-baseline' } | Select-Object -First 1
$modelPath = if ($modelRoot) { Join-Path (Join-Path $modelRoot 'checkpoints') $baseModel.filename } else { $null }
$modelExists = $modelPath -and (Test-Path -LiteralPath $modelPath)
Add-Check 'SDXL baseline model' $modelExists 'required' $(if ($modelPath) { $modelPath } else { 'model path not configured' })

if ($Deep -and $modelExists) {
    $actualHash = Get-XianxiaSha256 -Path $modelPath
    Add-Check 'SDXL SHA-256' ($actualHash -eq $baseModel.sha256) 'required' $actualHash
}

$gpu = Get-Command nvidia-smi -ErrorAction SilentlyContinue
Add-Check 'NVIDIA runtime' ($null -ne $gpu) 'attention' $(if ($gpu) { 'nvidia-smi available' } else { 'CPU/other GPU setup requires manual validation' })
Add-Check 'Notion mapping' (Test-Path -LiteralPath (Join-Path $projectRoot 'Docs\NOTION_SYNC.md')) 'required' 'Connector auth remains per user/host'

foreach ($check in $checks) {
    $status = if ($check.Passed) { 'OK' } elseif ($check.Level -eq 'required') { 'MISSING' } else { 'ATTENTION' }
    Write-Output ("{0,-22} {1,-10} {2}" -f $check.Name, $status, $check.Detail)
}

if ($checks | Where-Object { $_.Level -eq 'required' -and -not $_.Passed }) {
    exit 1
}

exit 0
