$ErrorActionPreference = 'Stop'
# Restore the checked RAM configuration and temporary row/direction controls.
# This script never writes configuration Flash.
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$archive = Join-Path $taskRoot 'baseline/robust_match_verified_20261025_0051'
$build = Join-Path $taskRoot 'build/robust_match'
$manifest = Get-Content -Raw -LiteralPath (Join-Path $archive 'manifest.json') | ConvertFrom-Json
foreach ($name in @('fusion.bit', 'fusion.ltx')) {
    $key = "build/robust_match/$name"
    $expected = $manifest.files_sha256.PSObject.Properties[$key].Value
    foreach ($path in @((Join-Path $archive $name), (Join-Path $build $name))) {
        if (-not $expected -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
            throw "Checked build hash mismatch: $path"
        }
    }
}
$hardwareScript = Join-Path $taskRoot 'tools/row_alignment_hw.tcl'
$expectedTool = $manifest.files_sha256.PSObject.Properties['tools/row_alignment_hw.tcl'].Value
if ((Get-FileHash -LiteralPath $hardwareScript -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedTool) {
    throw 'Hardware script changed since the checked archive; inspect it before restoring.'
}
$vivado = 'C:/Xilinx/Vivado/2019.1/bin/vivado.bat'
Push-Location -LiteralPath $taskRoot
try {
    & $vivado -mode batch -source $hardwareScript -log build/restore_robust_program.log -journal build/restore_robust_program.jou -tclargs program robust
    if ($LASTEXITCODE -ne 0) { throw 'FPGA programming failed' }
    & $vivado -mode batch -source $hardwareScript -log build/restore_robust_controls.log -journal build/restore_robust_controls.jou -tclargs set 219 robust
    if ($LASTEXITCODE -ne 0) { throw 'Temporary control restoration failed' }
} finally {
    Pop-Location
}
