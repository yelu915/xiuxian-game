param(
    [Parameter(Mandatory = $true)][string]$SourceImage,
    [string]$ApprovedName
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workflow.Common.ps1')

$projectRoot = Get-XianxiaProjectRoot
$generatedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'ArtSource\AI\Generated'))
$generatedPrefix = $generatedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$sourcePath = [IO.Path]::GetFullPath($SourceImage)

if (-not $sourcePath.StartsWith($generatedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Only files inside ArtSource/AI/Generated can be promoted by this command.'
}
if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source image not found: $sourcePath"
}

$sidecarPath = "$sourcePath.provenance.json"
if (-not (Test-Path -LiteralPath $sidecarPath)) {
    throw 'The matching provenance sidecar is required before approval.'
}

if ([string]::IsNullOrWhiteSpace($ApprovedName)) {
    $ApprovedName = Split-Path -Leaf $sourcePath
}
$ApprovedName = Split-Path -Leaf $ApprovedName
$approvedRoot = Join-Path $projectRoot 'ArtSource\AI\Approved'
New-Item -ItemType Directory -Force -Path $approvedRoot | Out-Null
$destination = Join-Path $approvedRoot $ApprovedName

if (Test-Path -LiteralPath $destination) {
    throw "Approved asset already exists: $destination"
}

Copy-Item -LiteralPath $sourcePath -Destination $destination
Copy-Item -LiteralPath $sidecarPath -Destination "$destination.provenance.json"
Write-Output ("Approved source asset: {0}" -f $destination)
Write-Output 'Review the Git diff and commit both the image and its provenance sidecar together.'
