param(
    [ValidateRange(0, 65535)][int]$Port = 0
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workflow.Common.ps1')

$projectRoot = Get-XianxiaProjectRoot
$settings = Get-XianxiaLocalSettings
$comfyRoot = Get-XianxiaSetting -Settings $settings -Name 'COMFYUI_ROOT'
$modelRoot = Get-XianxiaSetting -Settings $settings -Name 'COMFYUI_MODEL_ROOT'
if ($Port -eq 0) {
    $configuredBaseUrl = Get-XianxiaSetting -Settings $settings -Name 'COMFYUI_BASE_URL' -DefaultValue 'http://127.0.0.1:8190'
    $Port = ([uri]$configuredBaseUrl).Port
}

if ([string]::IsNullOrWhiteSpace($comfyRoot) -or [string]::IsNullOrWhiteSpace($modelRoot)) {
    throw 'COMFYUI_ROOT and COMFYUI_MODEL_ROOT are required. Run Tools/Bootstrap-Workstation.ps1 first.'
}

$portableMain = Join-Path $comfyRoot 'ComfyUI\main.py'
$portablePython = Join-Path $comfyRoot 'python_embeded\python.exe'
$alternatePython = Join-Path $comfyRoot 'python_embedded\python.exe'

if (-not (Test-Path -LiteralPath $portablePython) -and (Test-Path -LiteralPath $alternatePython)) {
    $portablePython = $alternatePython
}

if (-not (Test-Path -LiteralPath $portableMain) -or -not (Test-Path -LiteralPath $portablePython)) {
    throw "A complete ComfyUI portable runtime was not found at $comfyRoot. Run Bootstrap-Workstation.ps1 -InstallComfyUI."
}

$localDirectory = Join-Path $projectRoot '.local'
$outputDirectory = Join-Path $projectRoot 'ArtSource\AI\Generated'
New-Item -ItemType Directory -Force -Path $localDirectory, $outputDirectory | Out-Null

$yamlPath = Join-Path $localDirectory 'comfyui_extra_model_paths.yaml'
$modelPathYaml = ConvertTo-ForwardSlashPath $modelRoot
$yaml = @"
xianxiarogue_models:
  base_path: "$modelPathYaml"
  checkpoints: checkpoints
  clip: clip
  clip_vision: clip_vision
  configs: configs
  controlnet: controlnet
  diffusion_models: diffusion_models
  embeddings: embeddings
  loras: loras
  upscale_models: upscale_models
  vae: vae
"@
[IO.File]::WriteAllText($yamlPath, $yaml, [Text.UTF8Encoding]::new($false))

Write-Output ("Starting ComfyUI on http://127.0.0.1:{0}" -f $Port)
Write-Output ("Output directory: {0}" -f $outputDirectory)
Push-Location (Split-Path -Parent $portableMain)
try {
    & $portablePython -s $portableMain --listen 127.0.0.1 --port $Port --disable-auto-launch --output-directory $outputDirectory --extra-model-paths-config $yamlPath
} finally {
    Pop-Location
}
