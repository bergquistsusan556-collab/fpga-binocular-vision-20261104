set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint [file join $root build fusion synthesized.dcp]
puts "CLOCK_NET_DRIVERS=[get_pins -of_objects [get_nets clk_50m] -filter {DIRECTION == OUT}]"
puts "LCD_DIV=[get_pins -hier -filter {NAME =~ */divide2_reg/Q}]"
puts "SCCB=[get_pins -hier -filter {NAME =~ */dri_clk_reg/Q}]"
puts "VIDEO_NETS=[get_nets -hier -filter {NAME =~ *pipeline* && (NAME =~ *match* || NAME =~ *distance* || NAME =~ *out_x* || NAME =~ *out_y* || NAME =~ *out_de* || NAME =~ *orgb*)}]"
puts "RGB_NETS=[get_nets -hier -filter {NAME =~ *fetch* || NAME =~ *data_in* || NAME =~ *req_d*}]"
