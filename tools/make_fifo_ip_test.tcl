set root [file normalize [file join [file dirname [info script]] ..]]
set tdir [file join $root "tools" "fifo_ip_test"]
file delete -force $tdir
create_project fifo_ip_test $tdir -part xc7a35tfgg484-2 -force
set_property target_language Verilog [current_project]

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
    puts "IP_OK=$name"
}
exit 0
