$ErrorActionPreference = 'Stop'

function Get-XianxiaProjectRoot {
    return Split-Path -Parent $PSScriptRoot
}

function Get-XianxiaLocalSettings {
    $projectRoot = Get-XianxiaProjectRoot
    $settings = @{}
    $envFile = Join-Path $projectRoot '.env.local'

    if (Test-Path -LiteralPath $envFile) {
        foreach ($line in Get-Content -LiteralPath $envFile) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and -not $line.TrimStart().StartsWith('#')) {
                $settings[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
            }
        }
    }

    foreach ($name in 'COMFYUI_ROOT', 'COMFYUI_MODEL_ROOT', 'COMFYUI_BASE_URL') {
        $processValue = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not [string]::IsNullOrWhiteSpace($processValue)) {
            $settings[$name] = $processValue
        }
    }

    return $settings
}

function Get-XianxiaSetting {
    param(
        [hashtable]$Settings,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$DefaultValue
    )

    if ($Settings.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace($Settings[$Name])) {
        return $Settings[$Name]
    }

    return $DefaultValue
}

function ConvertTo-ForwardSlashPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return $Path.Replace('\', '/')
}

function Get-XianxiaSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($Path))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash($stream)
        return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}
