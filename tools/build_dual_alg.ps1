$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$vivado = "C:\Xilinx\Vivado\2019.1\bin\vivado.bat"
$tcl = Join-Path $root "tools\build_dual_alg_2019_full.tcl"
if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado 2019.1 not found: $vivado" }
& $vivado -mode batch -nojournal -nolog -source $tcl
exit $LASTEXITCODE
