set_property IOSTANDARD LVCMOS33 [get_ports *]

# Main Clock Signal 100 MHz
# 10 ns => 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
create_clock -name sys_clk -period 10.000 [get_ports clk]  

# Reset Signal
set_property PACKAGE_PIN U18 [get_ports { ctrl_reset }]



##Sch name = JB1
set_property PACKAGE_PIN A14 [get_ports {bus_data_in[0]}]
#Sch name = JB2
set_property PACKAGE_PIN A16 [get_ports {bus_data_in[1]}]
#Sch name = JB3
set_property PACKAGE_PIN B15 [get_ports {bus_data_in[2]}]
#Sch name = JB4
set_property PACKAGE_PIN B16 [get_ports {bus_data_in[3]}]
##Sch name = JB7
set_property PACKAGE_PIN A15 [get_ports {bus_data_in[4]}]
##Sch name = JB8
set_property PACKAGE_PIN A17 [get_ports {bus_data_in[5]}]
##Sch name = JB9
set_property PACKAGE_PIN C15 [get_ports {bus_data_in[6]}]
##Sch name = JB10
set_property PACKAGE_PIN C16 [get_ports {bus_data_in[7]}]



##Sch name = JC1
set_property PACKAGE_PIN K17 [get_ports {ctrl_start}]
##Sch name = JC2
set_property PACKAGE_PIN M18 [get_ports {ctrl_stop }]
##Sch name = JC3
set_property PACKAGE_PIN N17 [get_ports {ctrl_rw }]
##Sch name = JC4
set_property PACKAGE_PIN P18 [get_ports {i2c_sda }]
##Sch name = JC7
set_property PACKAGE_PIN L17 [get_ports {status_busy }]
##Sch name = JC8
set_property PACKAGE_PIN M19 [get_ports {status_done}]
##Sch name = JC9
set_property PACKAGE_PIN P17 [get_ports {status_error }]
##Sch name = JC10
set_property PACKAGE_PIN R18 [get_ports {i2c_scl }]


##Sch name = JA1
set_property PACKAGE_PIN J1 [get_ports {bus_data_out[0]} ]
##Sch name = JA2
set_property PACKAGE_PIN L2 [get_ports {bus_data_out[1]} ]
##Sch name = JA3
set_property PACKAGE_PIN J2 [get_ports {bus_data_out[2]}]
##Sch name = JA4
set_property PACKAGE_PIN G2 [get_ports {bus_data_out[3]}]
##Sch name = JA7
set_property PACKAGE_PIN H1 [get_ports {bus_data_out[4]}]
##Sch name = JA8
set_property PACKAGE_PIN K2 [get_ports {bus_data_out[5]}]
##Sch name = JA9
set_property PACKAGE_PIN H2 [get_ports {bus_data_out[6]}]
##Sch name = JA10
set_property PACKAGE_PIN G3 [get_ports {bus_data_out[7]}]