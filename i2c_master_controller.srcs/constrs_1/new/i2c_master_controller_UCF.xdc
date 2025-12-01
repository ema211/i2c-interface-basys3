set_property IOSTANDARD LVCMOS33 [get_ports *]

# Main Clock Signal 100 MHz
# 10 ns => 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
create_clock -name sys_clk -period 10.000 [get_ports clk]  

# Reset Signal
set_property PACKAGE_PIN U18 [get_ports { btnC }]

##Sch name = JC1
set_property PACKAGE_PIN K17 [get_ports {sda}]

##Sch name = JC2
set_property PACKAGE_PIN M18 [get_ports {scl}]

set_property PULLUP true [get_ports {sda}]
set_property PULLUP true [get_ports {scl}]



#Display 7 segmentos
set_property PACKAGE_PIN W7 [get_ports {Seg[0]}]  
set_property PACKAGE_PIN W6 [get_ports {Seg[1]}]  
set_property PACKAGE_PIN U8 [get_ports {Seg[2]}]  
set_property PACKAGE_PIN V8 [get_ports {Seg[3]}]  
set_property PACKAGE_PIN U5 [get_ports {Seg[4]}]  
set_property PACKAGE_PIN V5 [get_ports {Seg[5]}]  
set_property PACKAGE_PIN U7 [get_ports {Seg[6]}]  

## Transistores (anodos comunes de cada display)
set_property PACKAGE_PIN U2 [get_ports {T[0]}]  
set_property PACKAGE_PIN U4 [get_ports {T[1]}]  
set_property PACKAGE_PIN V4 [get_ports {T[2]}]  
set_property PACKAGE_PIN W4 [get_ports {T[3]}]  
