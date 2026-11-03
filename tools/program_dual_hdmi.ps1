$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$vivado = "C:\Xilinx\Vivado\2019.1\bin\vivado.bat"
$hwServer = "C:\Xilinx\Vivado\2019.1\bin\hw_server.bat"
$tcl = Join-Path $root "tools\program_dual_hdmi.tcl"
$bit = Join-Path $root "Verilog\60_top_dual_ov5640_hdmi\prj\top_dual_ov5640_hdmi.runs\impl_1\top_dual_ov5640_hdmi.bit"

if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado 2019.1 not found: $vivado" }
if (-not (Test-Path -LiteralPath $bit)) { throw "Bitstream not found: $bit" }

$listening = $false
try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $client.Connect("127.0.0.1", 3121)
    $listening = $client.Connected
    $client.Close()
} catch { }

if (-not $listening) {
    Start-Process -FilePath $hwServer -WorkingDirectory $root -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 3
}

& $vivado -mode batch -nojournal -nolog -source $tcl -tclargs $bit
exit $LASTEXITCODE