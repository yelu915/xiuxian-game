param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$NegativePrompt = 'blurry, low quality, deformed, extra limbs, bad anatomy, watermark, signature, text, cropped, jpeg artifacts',
    [long]$Seed = 20260825,
    [ValidateRange(256, 2048)][int]$Width = 1024,
    [ValidateRange(256, 2048)][int]$Height = 1024,
    [ValidateRange(1, 100)][int]$Steps = 30,
    [ValidateRange(1.0, 30.0)][double]$Cfg = 7.5,
    [string]$FilenamePrefix = 'xianxiarogue_concept',
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workflow.Common.ps1')

$projectRoot = Get-XianxiaProjectRoot
$settings = Get-XianxiaLocalSettings
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = Get-XianxiaSetting -Settings $settings -Name 'COMFYUI_BASE_URL' -DefaultValue 'http://127.0.0.1:8190'
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')

$workflowPath = Join-Path $projectRoot 'AI\workflows\sdxl_concept_v1.json'
$workflow = Get-Content -LiteralPath $workflowPath -Raw | ConvertFrom-Json
$workflow.'3'.inputs.seed = $Seed
$workflow.'3'.inputs.steps = $Steps
$workflow.'3'.inputs.cfg = $Cfg
$workflow.'5'.inputs.width = $Width
$workflow.'5'.inputs.height = $Height
$workflow.'6'.inputs.text = $Prompt
$workflow.'7'.inputs.text = $NegativePrompt
$workflow.'9'.inputs.filename_prefix = $FilenamePrefix

try {
    Invoke-RestMethod -Uri ("{0}/system_stats" -f $ApiBaseUrl) -TimeoutSec 5 | Out-Null
} catch {
    throw "ComfyUI is not reachable at $ApiBaseUrl. Start Tools/Start-ImageLab.ps1 first."
}

$clientId = [guid]::NewGuid().ToString()
$requestBody = @{ client_id = $clientId; prompt = $workflow } | ConvertTo-Json -Depth 100
$queued = Invoke-RestMethod -Uri ("{0}/prompt" -f $ApiBaseUrl) -Method Post -ContentType 'application/json' -Body $requestBody
$promptId = $queued.prompt_id
if ([string]::IsNullOrWhiteSpace($promptId)) {
    throw 'ComfyUI did not return a prompt_id.'
}

Write-Output ("Queued generation {0}" -f $promptId)
$deadline = (Get-Date).AddMinutes(10)
$historyEntry = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    $history = Invoke-RestMethod -Uri ("{0}/history/{1}" -f $ApiBaseUrl, $promptId)
    $property = $history.PSObject.Properties[$promptId]
    if ($property -and $property.Value.outputs) {
        $historyEntry = $property.Value
        break
    }
}

if (-not $historyEntry) {
    throw "Generation $promptId did not finish within 10 minutes."
}

$generatedDirectory = Join-Path $projectRoot 'ArtSource\AI\Generated'
New-Item -ItemType Directory -Force -Path $generatedDirectory | Out-Null
$workflowHash = Get-XianxiaSha256 -Path $workflowPath
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'AI\models.lock.json') -Raw | ConvertFrom-Json
$baseModel = $lock.models | Where-Object { $_.status -eq 'approved-baseline' } | Select-Object -First 1
$savedFiles = @()

foreach ($nodeProperty in $historyEntry.outputs.PSObject.Properties) {
    foreach ($image in @($nodeProperty.Value.images)) {
        if (-not $image) { continue }
        $safeName = Split-Path -Leaf $image.filename
        $localPath = Join-Path $generatedDirectory $safeName
        if (-not (Test-Path -LiteralPath $localPath)) {
            $query = 'filename={0}&subfolder={1}&type={2}' -f [uri]::EscapeDataString($image.filename), [uri]::EscapeDataString($image.subfolder), [uri]::EscapeDataString($image.type)
            Invoke-WebRequest -Uri ("{0}/view?{1}" -f $ApiBaseUrl, $query) -OutFile $localPath
        }

        $outputHash = Get-XianxiaSha256 -Path $localPath
        $record = [ordered]@{
            schema_version = 1
            created_at_utc = [DateTime]::UtcNow.ToString('o')
            generator = 'ComfyUI API'
            prompt_id = $promptId
            workflow = [ordered]@{ path = 'AI/workflows/sdxl_concept_v1.json'; sha256 = $workflowHash }
            model = [ordered]@{ filename = $baseModel.filename; sha256 = $baseModel.sha256 }
            prompt = $Prompt
            negative_prompt = $NegativePrompt
            seed = $Seed
            settings = [ordered]@{ width = $Width; height = $Height; steps = $Steps; cfg = $Cfg; sampler = 'euler_ancestral'; scheduler = 'normal' }
            output = [ordered]@{ filename = $safeName; sha256 = $outputHash }
        }
        $sidecarPath = "$localPath.provenance.json"
        [IO.File]::WriteAllText($sidecarPath, ($record | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
        $savedFiles += $localPath
        Write-Output ("Generated: {0}" -f $localPath)
        Write-Output ("Provenance: {0}" -f $sidecarPath)
    }
}

if ($savedFiles.Count -eq 0) {
    throw 'The workflow completed but returned no image outputs.'
}
