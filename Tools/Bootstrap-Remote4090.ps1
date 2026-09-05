param(
    [string]$RepoPath,
    [string]$RepoUrl = 'https://github.com/yelu915/xiuxian-game.git',
    [switch]$InstallGit,
    [switch]$InstallComfyUI,
    [switch]$DownloadBaseModel
)

# 在 4090 机上运行的半自动引导。交互/需要登录的部分(GitHub、Unity Hub、
# Tailscale、Actions runner 注册)仍需人工，见 Docs/SETUP_REMOTE_4090.md。
$ErrorActionPreference = 'Stop'

function Info($m) { Write-Host "[4090] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[4090] WARN: $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[4090] ERROR: $m" -ForegroundColor Red; exit 1 }

# --- 0. 定位仓库根 ---
if (-not $RepoPath) {
    $parent = Split-Path -Parent $PSScriptRoot
    if (Test-Path -LiteralPath (Join-Path $parent '.git')) {
        $RepoPath = $parent
    } else {
        Fail 'Run this script from inside a clone, or pass -RepoPath.'
    }
}
$RepoPath = [IO.Path]::GetFullPath($RepoPath)

# --- 1. Git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if ($InstallGit) {
        Info 'Installing Git for Windows...'
        winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Fail 'Git install failed. Re-run after install and restarting the shell.' }
        Warn 'Git installed - restart this PowerShell so PATH takes effect, then re-run.'
        exit 0
    }
    Fail 'Git is missing. Re-run with -InstallGit, or install Git for Windows first.'
}

# --- 2. Clone + LFS ---
if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) {
    New-Item -ItemType Directory -Force -Path $RepoPath | Out-Null
    Info "Cloning $RepoUrl ..."
    git clone $RepoUrl $RepoPath
    if ($LASTEXITCODE -ne 0) { Fail 'Clone failed. Check GitHub credentials (PAT or gh auth login).' }
}
Push-Location $RepoPath
try {
    Info 'Pulling LFS objects...'
    git lfs install --local
    git lfs pull

    # --- 3. Unity 版本校验 ---
    $unityExe = Join-Path $env:LOCALAPPDATA 'Unity\Editors\6000.3.22f1\Editor\Unity.exe'
    if (-not (Test-Path -LiteralPath $unityExe)) {
        Fail @"
Unity 6000.3.22f1 is missing.
Install via Unity Hub (Settings > Installs > Install Editor > 6000.3.22f1, add Windows Build Support).
See Docs/SETUP_REMOTE_4090.md step 3, then re-run.
"@
    }
    Info "Unity OK: $unityExe"

    # --- 4. AI 产线部署 (可选开关) ---
    if ($InstallComfyUI -or $DownloadBaseModel) {
        Info 'Deploying AI pipeline (ComfyUI + base model, hash-verified)...'
        $bootstrap = Join-Path $PSScriptRoot 'Bootstrap-Workstation.ps1'
        if (-not (Test-Path -LiteralPath $bootstrap)) { Fail 'Bootstrap-Workstation.ps1 not found next to this script.' }
        $args = @()
        if ($InstallComfyUI) { $args += '-InstallComfyUI' }
        if ($DownloadBaseModel) { $args += '-DownloadBaseModel' }
        & $bootstrap @args
        if ($LASTEXITCODE -ne 0) { Fail 'AI pipeline bootstrap failed.' }
    }

    # --- 5. 尾部提示 ---
    Info 'Repo ready. Remaining manual steps:'
    Write-Host @"
  1) Unity Hub: sign in once so the license is active.
  2) Tailscale:  tailscale up   (must be ONLINE - the laptop reaches this box over the tailnet)
  3) ComfyUI:    .\Tools\Start-ImageLab.ps1 -ListenAddress <this-tailscale-ip>
  4) Actions runner: register per Docs/SETUP_REMOTE_4090.md step 7 (labels: windows,gpu-4090)
     and set machine env var: XIANXIA_UNITY_EXE=$unityExe
"@ -ForegroundColor Gray
} finally {
    Pop-Location
}
