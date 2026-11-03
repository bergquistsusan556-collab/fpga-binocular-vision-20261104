proc glob_recursive {dir pattern} {
    set result {}
    foreach item [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $item]} {
            set result [concat $result [glob_recursive $item $pattern]]
        } elseif {[string match $pattern [file tail $item]]} {
            lappend result $item
        }
    }
    return $result
}

set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir ..]]
set proj [file join $root "Verilog" "60_top_dual_ov5640_hdmi"]
set rtl [file join $proj "rtl"]
set rtl_alg [file join $proj "rtl_alg"]
set ip [file join $proj "prj" "top_dual_ov5640_hdmi.srcs" "sources_1" "ip"]
set xdc [file join $proj "prj" "top_dual_ov5640_hdmi.srcs" "constrs_1" "new" "pin.xdc"]
set out [file join $proj "prj" "top_dual_ov5640_hdmi.runs" "impl_1" "top_dual_ov5640_hdmi_alg.bit"]
set xpm_root "C:/Xilinx/Vivado/2019.1/data/ip/xpm"

read_verilog -sv [list [file join $xpm_root "xpm_cdc" "hdl" "xpm_cdc.sv"] [file join $xpm_root "xpm_memory" "hdl" "xpm_memory.sv"] [file join $xpm_root "xpm_fifo" "hdl" "xpm_fifo.sv"]]

set rtl_files [lsort [glob -nocomplain [file join $rtl "*.v"]]]
read_verilog $rtl_files
read_verilog -sv [list [file join $rtl_alg "rd_fifo.sv"] [file join $rtl_alg "wr_fifo.sv"]]

set clk_files [list [file join $ip "clk_wiz_0_1" "clk_wiz_0.v"] [file join $ip "clk_wiz_0_1" "clk_wiz_0_clk_wiz.v"]]
read_verilog $clk_files

set mig_rtl [file join $ip "mig_7series_0" "mig_7series_0" "user_design" "rtl"]
set mig_files [glob_recursive $mig_rtl "*.v"]
set mig_files [lsearch -all -inline -not -regexp $mig_files {_sim\.v$}]
read_verilog $mig_files

read_xdc [list $xdc]
read_xdc [list [file join $ip "mig_7series_0" "mig_7series_0" "user_design" "constraints" "mig_7series_0.xdc"]]

synth_design -top top_dual_ov5640_hdmi -part xc7a35tfgg484-2 -flatten_hierarchy rebuilt
opt_design
place_design
route_design
write_bitstream -force $out
puts "BUILD_OK=$out"
exit 0
