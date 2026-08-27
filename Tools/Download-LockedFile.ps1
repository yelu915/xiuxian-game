param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][long]$TotalBytes,
    [Parameter(Mandatory = $true)][string]$Sha256,
    [ValidateRange(1, 16)][int]$Connections = 4,
    [ValidateRange(8, 256)][int]$SegmentSizeMB = 48
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workflow.Common.ps1')
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $curl) {
    throw 'curl.exe is required for the locked large-file download.'
}

$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputParent = [IO.Path]::GetFullPath((Split-Path -Parent $OutputPath))
New-Item -ItemType Directory -Force -Path $outputParent | Out-Null

$prefixBytes = 0L
if (Test-Path -LiteralPath $OutputPath) {
    $prefixBytes = (Get-Item -LiteralPath $OutputPath).Length
    if ($prefixBytes -gt $TotalBytes) {
        throw 'The existing partial file is larger than the locked file size. It was not modified.'
    }
    if ($prefixBytes -eq $TotalBytes) {
        $existingHash = Get-XianxiaSha256 -Path $OutputPath
        if ($existingHash -eq $Sha256.ToLowerInvariant()) {
            Write-Output 'Locked download already complete and verified.'
            exit 0
        }
        throw 'The existing complete-size file has the wrong SHA-256. It was not modified.'
    }
}

$segmentRoot = [IO.Path]::GetFullPath("$OutputPath.segments")
$assemblyPath = [IO.Path]::GetFullPath("$OutputPath.assembled")
$parentPrefix = $outputParent.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $segmentRoot.StartsWith($parentPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not $assemblyPath.StartsWith($parentPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'A derived download path escaped the intended download directory.'
}

if ((Test-Path -LiteralPath $assemblyPath) -and (Get-Item -LiteralPath $assemblyPath).Length -eq $TotalBytes) {
    $assembledHash = Get-XianxiaSha256 -Path $assemblyPath
    if ($assembledHash -eq $Sha256.ToLowerInvariant()) {
        if (Test-Path -LiteralPath $OutputPath) {
            Remove-Item -LiteralPath $OutputPath -Force
        }
        Move-Item -LiteralPath $assemblyPath -Destination $OutputPath
        if (Test-Path -LiteralPath $segmentRoot) {
            Remove-Item -LiteralPath $segmentRoot -Recurse -Force
        }
        Write-Output ("Verified recovered download: {0}" -f $OutputPath)
        exit 0
    }
}
New-Item -ItemType Directory -Force -Path $segmentRoot | Out-Null

$segmentBytes = [long]$SegmentSizeMB * 1MB
$pending = [Collections.Generic.Queue[object]]::new()
for ($start = $prefixBytes; $start -lt $TotalBytes; $start += $segmentBytes) {
    $end = [Math]::Min($start + $segmentBytes - 1, $TotalBytes - 1)
    $partPath = Join-Path $segmentRoot ("{0:D12}-{1:D12}.part" -f $start, $end)
    $expectedLength = $end - $start + 1
    if ((Test-Path -LiteralPath $partPath) -and (Get-Item -LiteralPath $partPath).Length -eq $expectedLength) {
        continue
    }
    $pending.Enqueue([pscustomobject]@{ Start = $start; End = $end; Path = $partPath; ExpectedLength = $expectedLength })
}

$active = [Collections.ArrayList]::new()
try {
    while ($pending.Count -gt 0 -or $active.Count -gt 0) {
        while ($pending.Count -gt 0 -and $active.Count -lt $Connections) {
            $segment = $pending.Dequeue()
            $arguments = @(
                '--location', '--fail', '--silent', '--show-error',
                '--retry', '10', '--retry-all-errors', '--retry-delay', '2',
                '--range', ("{0}-{1}" -f $segment.Start, $segment.End),
                '--output', $segment.Path,
                $Uri
            )
            $process = Start-Process -FilePath $curl.Source -ArgumentList $arguments -WindowStyle Hidden -PassThru
            [void]$active.Add([pscustomobject]@{ Process = $process; Segment = $segment })
        }

        Start-Sleep -Milliseconds 500
        foreach ($item in @($active)) {
            if (-not $item.Process.HasExited) { continue }
            $item.Process.WaitForExit()
            $exitCode = $item.Process.ExitCode
            $item.Process.Dispose()
            [void]$active.Remove($item)

            if ($exitCode -ne 0) {
                throw ("Segment {0}-{1} failed with curl exit code {2}." -f $item.Segment.Start, $item.Segment.End, $exitCode)
            }
            $actualLength = (Get-Item -LiteralPath $item.Segment.Path).Length
            if ($actualLength -ne $item.Segment.ExpectedLength) {
                throw ("Segment {0}-{1} has length {2}; expected {3}." -f $item.Segment.Start, $item.Segment.End, $actualLength, $item.Segment.ExpectedLength)
            }

            $completedBytes = $prefixBytes
            Get-ChildItem -LiteralPath $segmentRoot -File -Filter '*.part' | ForEach-Object { $completedBytes += $_.Length }
            Write-Output ("Downloaded {0:N1}% ({1:N1} MB / {2:N1} MB)" -f (($completedBytes / $TotalBytes) * 100), ($completedBytes / 1MB), ($TotalBytes / 1MB))
        }
    }
} catch {
    foreach ($item in @($active)) {
        if (-not $item.Process.HasExited) {
            $item.Process.Kill()
            $item.Process.WaitForExit()
        }
        $item.Process.Dispose()
    }
    throw
}

if (Test-Path -LiteralPath $assemblyPath) {
    Remove-Item -LiteralPath $assemblyPath -Force
}

$destination = [IO.File]::Open($assemblyPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    if ($prefixBytes -gt 0) {
        $source = [IO.File]::Open($OutputPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { $source.CopyTo($destination) } finally { $source.Dispose() }
    }
    Get-ChildItem -LiteralPath $segmentRoot -File -Filter '*.part' | Sort-Object Name | ForEach-Object {
        $source = [IO.File]::Open($_.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { $source.CopyTo($destination) } finally { $source.Dispose() }
    }
} finally {
    $destination.Dispose()
}

if ((Get-Item -LiteralPath $assemblyPath).Length -ne $TotalBytes) {
    throw 'Assembled download length did not match the lock file.'
}
$actualHash = Get-XianxiaSha256 -Path $assemblyPath
if ($actualHash -ne $Sha256.ToLowerInvariant()) {
    throw 'Assembled download SHA-256 did not match the lock file.'
}

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}
Move-Item -LiteralPath $assemblyPath -Destination $OutputPath
Remove-Item -LiteralPath $segmentRoot -Recurse -Force
Write-Output ("Verified locked download: {0}" -f $OutputPath)
