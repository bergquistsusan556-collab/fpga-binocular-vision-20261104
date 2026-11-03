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
set src [file join $root "Verilog" "59_top_dual_ov5640_lcd"]
set prjdir [file join $root "Verilog" "59_top_dual_ov5640_lcd_alg2019"]
file delete -force $prjdir
create_project lcd_alg2019 $prjdir -part xc7a35tfgg484-2 -force
set_property target_language Verilog [current_project]

# Original RTL, including the LCD-alg changes already made in this workspace.
add_files -norecurse [lsort [glob -nocomplain [file join $src "rtl" "*.v"]]]

# Generated clock-wizard RTL from the original project.
set ip [file join $src "prj" "top_dual_ov5640_lcd.srcs" "sources_1" "ip"]
add_files -norecurse [list [file join $ip "clk_wiz_0_1" "clk_wiz_0.v"] [file join $ip "clk_wiz_0_1" "clk_wiz_0_clk_wiz.v"]]

# Generated MIG RTL, but exclude the simulation-only model.
set mig_rtl [file join $ip "mig_7series_0" "mig_7series_0" "user_design" "rtl"]
set mig_files [glob_recursive $mig_rtl "*.v"]
set mig_files [lsearch -all -inline -not -regexp $mig_files {_sim\.v$}]
add_files -norecurse $mig_files

# Recreate the two FIFO Generator cores with the 2019.1 IP catalog.
foreach name {rd_fifo wr_fifo} {
    create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name $name
    set cfg [list \
        CONFIG.INTERFACE_TYPE {Native} \
        CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
        CONFIG.Input_Data_Width {128} \
        CONFIG.Input_Depth {512} \
        CONFIG.Output_Data_Width {128} \
        CONFIG.READ_WRITE_MODE {READ_WRITE} \
        CONFIG.Performance_Options {First_Word_Fall_Through} \
        CONFIG.Reset_Type {Asynchronous_Reset} \
        CONFIG.Read_Data_Count {true} \
        CONFIG.Write_Data_Count {true} \
        CONFIG.Data_Count_Width {9} \
        CONFIG.Read_Data_Count_Width {9} \
        CONFIG.Write_Data_Count_Width {9} \
        CONFIG.Enable_Reset_Synchronization {true} \
        CONFIG.synchronization_stages {2} \
        CONFIG.Use_Dout_Reset {true} \
        CONFIG.Dout_Reset_Value {0} \
        CONFIG.Full_Flags_Reset_Value {1} \
        CONFIG.Almost_Empty_Flag {false} \
        CONFIG.Almost_Full_Flag {false} \
        CONFIG.Valid_Flag {false} \
        CONFIG.Programmable_Empty_Type {No_Programmable_Empty_Threshold} \
        CONFIG.Programmable_Full_Type {No_Programmable_Full_Threshold} \
        CONFIG.Enable_ECC {false} \
    ]
    set_property -dict $cfg [get_ips $name]
    generate_target all [get_ips $name]
}

add_files -fileset constrs_1 -norecurse [list [file join $src "prj" "top_dual_ov5640_lcd.srcs" "constrs_1" "new" "pin.xdc"]]
add_files -fileset constrs_1 -norecurse [list [file join $ip "mig_7series_0" "mig_7series_0" "user_design" "constraints" "mig_7series_0.xdc"]]

set_property top top_dual_ov5640_lcd [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { puts "SYNTH_FAIL"; exit 2 }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} { puts "IMPL_FAIL"; exit 3 }
set src_bit [file join $prjdir "lcd_alg2019.runs" "impl_1" "top_dual_ov5640_lcd.bit"]
set dst_bit [file join $src "prj" "top_dual_ov5640_lcd.runs" "impl_1" "top_dual_ov5640_lcd_alg_ip.bit"]
file copy -force $src_bit $dst_bit
puts "BUILD_OK=$dst_bit"
exit 0
