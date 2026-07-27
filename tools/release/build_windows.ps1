[CmdletBinding()]
param(
    [string]$GodotExe = "",
    [string]$RceditExe = "",
    [switch]$SkipSmokeTest,
    [switch]$SkipVisualTest
)

$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$buildDir = Join-Path $projectRoot "build"
$outputExe = Join-Path $buildDir "PixelPathfinder.exe"
$releaseDir = Join-Path $projectRoot "release"
$releaseBaseName = "PixelPathfinder-v2.0.0-Windows-x64"
$releaseExe = Join-Path $releaseDir ($releaseBaseName + ".exe")
$releaseHashes = Join-Path $releaseDir "SHA256SUMS.txt"
$reportDir = Join-Path $buildDir "reports"
$workspaceToolchain = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\_toolchains\godot-4.3\editor\Godot_v4.3-stable_win64_console.exe"))

function Resolve-Godot43 {
    param([string]$Requested)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Requested) { $candidates.Add($Requested) }
    if ($env:GODOT4_3_EXE) { $candidates.Add($env:GODOT4_3_EXE) }
    $candidates.Add($workspaceToolchain)
    $candidates.Add("D:\Godot_v4.3-stable_win64_console.exe")
    $candidates.Add("D:\Godot_v4.3-stable_win64.exe")

    foreach ($commandName in @("godot", "godot4", "Godot_v4.3-stable_win64_console.exe", "Godot_v4.3-stable_win64.exe")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) { $candidates.Add($command.Source) }
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $resolved = [System.IO.Path]::GetFullPath($candidate)
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { continue }
        $version = (& $resolved --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $version.StartsWith("4.3.stable")) {
            return [pscustomobject]@{ Path = $resolved; Version = $version }
        }
    }
    throw "Godot 4.3 stable was not found. Set GODOT4_3_EXE or pass -GodotExe."
}

function Invoke-GodotStep {
    param(
        [string]$Label,
        [string[]]$Arguments
    )
    Write-Host "[$Label] $($Arguments -join ' ')"
    & $script:Godot.Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Resolve-Rcedit {
    param(
        [string]$Requested,
        [string]$GodotPath
    )
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Requested) { $candidates.Add($Requested) }
    if ($env:RCEDIT_EXE) { $candidates.Add($env:RCEDIT_EXE) }
    $godotToolchainRoot = Split-Path -Parent (Split-Path -Parent $GodotPath)
    $candidates.Add((Join-Path $godotToolchainRoot "rcedit\rcedit-x64.exe"))
    $candidates.Add((Join-Path (Split-Path -Parent $projectRoot) "_toolchains\godot-4.3\rcedit\rcedit-x64.exe"))

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $resolved = [System.IO.Path]::GetFullPath($candidate)
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            return $resolved
        }
    }
    throw "rcedit-x64.exe was not found. Set RCEDIT_EXE or pass -RceditExe."
}

function Assert-WindowsX64PE {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw "Export is not an MZ executable." }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Export has no PE signature." }
        $machine = $reader.ReadUInt16()
        if ($machine -ne 0x8664) { throw ("Export is not x86_64 PE (machine=0x{0:X4})." -f $machine) }
    }
    finally {
        $stream.Dispose()
    }
}

$script:Godot = Resolve-Godot43 -Requested $GodotExe
$script:Rcedit = Resolve-Rcedit -Requested $RceditExe -GodotPath $script:Godot.Path
Write-Host "Using $($script:Godot.Path)"
Write-Host "Version $($script:Godot.Version)"
Write-Host "Using rcedit $script:Rcedit"

$templateRoot = Join-Path $env:APPDATA "Godot\export_templates\4.3.stable"
$releaseTemplate = Join-Path $templateRoot "windows_release_x86_64.exe"
if (-not (Test-Path -LiteralPath $releaseTemplate -PathType Leaf)) {
    throw "Matching Godot 4.3 Windows export template is missing: $releaseTemplate"
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
if (Test-Path -LiteralPath $outputExe) {
    Remove-Item -LiteralPath $outputExe -Force
}

Push-Location $projectRoot
try {
    Invoke-GodotStep "IMPORT" @("--headless", "--path", $projectRoot, "--import")
    if (-not $SkipSmokeTest) {
        Invoke-GodotStep "SMOKE" @("--headless", "--path", $projectRoot, "res://tests/smoke_test.tscn")
    }
    if (-not $SkipVisualTest) {
        Invoke-GodotStep "VISUAL" @("--headless", "--path", $projectRoot, "res://tests/visual_integration_test.tscn")
    }
    Invoke-GodotStep "EXPORT" @("--headless", "--path", $projectRoot, "--export-release", "Windows Desktop", $outputExe)
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $outputExe -PathType Leaf)) {
    throw "Export completed without creating $outputExe"
}
$file = Get-Item -LiteralPath $outputExe
if ($file.Length -lt 10MB) {
    throw "Export is unexpectedly small: $($file.Length) bytes"
}
Assert-WindowsX64PE -Path $outputExe

& $script:Rcedit $outputExe `
    --set-file-version "2.0.0.0" `
    --set-product-version "2.0.0.0" `
    --set-version-string "CompanyName" "Pixel Pathfinder Contributors" `
    --set-version-string "ProductName" "Pixel Pathfinder" `
    --set-version-string "FileDescription" "Pixel Pathfinder" `
    --set-version-string "LegalCopyright" "Copyright (c) 2026 Jizhou Hu, Hebin Cui, Chengyao Zhu"
if ($LASTEXITCODE -ne 0) {
    throw "rcedit failed with exit code $LASTEXITCODE."
}

$versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($outputExe)
if ($versionInfo.FileVersion -ne "2.0.0.0") {
    throw "Windows FileVersion mismatch: expected 2.0.0.0, got $($versionInfo.FileVersion)"
}
if ($versionInfo.ProductVersion -ne "2.0.0.0") {
    throw "Windows ProductVersion mismatch: expected 2.0.0.0, got $($versionInfo.ProductVersion)"
}

$sidecarPck = Get-ChildItem -LiteralPath $buildDir -File -Filter "*.pck" -ErrorAction SilentlyContinue
if ($sidecarPck) {
    throw "Single-file export invariant failed: sidecar PCK exists."
}

$hash = (Get-FileHash -LiteralPath $outputExe -Algorithm SHA256).Hash

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
Copy-Item -LiteralPath $outputExe -Destination $releaseExe -Force
$releaseExeHash = (Get-FileHash -LiteralPath $releaseExe -Algorithm SHA256).Hash
@(
    "$releaseExeHash  $([System.IO.Path]::GetFileName($releaseExe))"
) | Set-Content -LiteralPath $releaseHashes -Encoding ASCII

$result = [ordered]@{
    status = "PASS"
    godot_exe = $script:Godot.Path
    godot_version = $script:Godot.Version
    rcedit_exe = $script:Rcedit
    export_preset = "Windows Desktop"
    output = $outputExe
    bytes = $file.Length
    sha256 = $hash
    created_utc = $file.LastWriteTimeUtc.ToString("o")
    pe_machine = "x86_64"
    file_version = $versionInfo.FileVersion
    product_version = $versionInfo.ProductVersion
    embedded_pck_configured = $true
    sidecar_pck_count = 0
    release_exe = $releaseExe
    release_exe_sha256 = $releaseExeHash
    release_hashes = $releaseHashes
}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportDir "Build_Windows_Result.json") -Encoding UTF8

Write-Host "PASS: $outputExe"
Write-Host "Bytes: $($file.Length)"
Write-Host "SHA256: $hash"
Write-Host "Release EXE: $releaseExe"
Write-Host "Release hashes: $releaseHashes"
