param([ValidateSet('video','robust')][string]$Version = 'video')
$ErrorActionPreference = 'Stop'
# Verify archived bit/LTX and extract its exact hardware helper. JTAG RAM only.
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if ($Version -eq 'video') {
    $archiveName = 'video_fusion_checked_20261028'
    $variant = 'video_fusion'
} else {
    $archiveName = 'robust_match_verified_20261025_0051'
    $variant = 'robust_match'
}
$archivePath = Join-Path $taskRoot "baseline/$archiveName"
$manifest = Get-Content -Raw -LiteralPath (Join-Path $archivePath 'manifest.json') | ConvertFrom-Json
foreach ($name in @('fusion.bit','fusion.ltx')) {
    $expected = $manifest.files_sha256.PSObject.Properties["build/$variant/$name"].Value
    foreach ($path in @((Join-Path $archivePath $name),(Join-Path $taskRoot "build/$variant/$name"))) {
        if (-not $expected -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
            throw "Checked artifact hash mismatch: $path"
        }
    }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$cachePath = Join-Path $taskRoot '.cache'
[System.IO.Directory]::CreateDirectory($cachePath) | Out-Null
# Kept one folder below project root, matching the archived Tcl root calculation.
$helperPath = Join-Path $cachePath "restore_${variant}_hw.tcl"
$zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $archivePath 'source.zip'))
try {
    $entry = $zip.GetEntry('tools/row_alignment_hw.tcl')
    if (-not $entry) { throw 'Archived hardware helper missing' }
    $inputStream = $entry.Open()
    $outputStream = [System.IO.File]::Create($helperPath)
    try { $inputStream.CopyTo($outputStream) } finally { $inputStream.Dispose(); $outputStream.Dispose() }
} finally { $zip.Dispose() }
$expectedHelper = $manifest.files_sha256.PSObject.Properties['tools/row_alignment_hw.tcl'].Value
if ((Get-FileHash -LiteralPath $helperPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHelper) {
    throw 'Archived hardware helper hash mismatch'
}
$vivado = 'C:/Xilinx/Vivado/2019.1/bin/vivado.bat'
Push-Location -LiteralPath $taskRoot
try {
    & $vivado -mode batch -source $helperPath -log "build/restore_${variant}_program.log" -journal "build/restore_${variant}_program.jou" -tclargs program $Version
    if ($LASTEXITCODE -ne 0) { throw 'Programming failed' }
    & $vivado -mode batch -source $helperPath -log "build/restore_${variant}_control.log" -journal "build/restore_${variant}_control.jou" -tclargs set 219 $Version
    if ($LASTEXITCODE -ne 0) { throw 'Control restoration failed' }
} finally { Pop-Location }
