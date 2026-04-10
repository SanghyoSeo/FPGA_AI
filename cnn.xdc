## ----------------------------------------------------------------------------
## Clock Signal
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## ----------------------------------------------------------------------------
## Switches (Zybo Z7-20)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];

## ----------------------------------------------------------------------------
## Buttons
## ----------------------------------------------------------------------------
# BTN0 -> reset_n
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { reset_n }];
# BTN1 -> btn_u
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { btn_u }];
# BTN2 -> btn_d
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports { btn_d }];

## ----------------------------------------------------------------------------
## LEDs
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## ----------------------------------------------------------------------------
## HDMI TX (TMDS)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17   IOSTANDARD TMDS_33 } [get_ports { tmds_clk_n }];
set_property -dict { PACKAGE_PIN H16   IOSTANDARD TMDS_33 } [get_ports { tmds_clk_p }];

set_property -dict { PACKAGE_PIN D20   IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[0] }];
set_property -dict { PACKAGE_PIN D19   IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[0] }];

set_property -dict { PACKAGE_PIN B20   IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[1] }];
set_property -dict { PACKAGE_PIN C20   IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[1] }];

set_property -dict { PACKAGE_PIN A20   IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[2] }];
set_property -dict { PACKAGE_PIN B19   IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[2] }];

## ----------------------------------------------------------------------------
## OV7670 Camera Interface (Pmod JB, JC)
## ----------------------------------------------------------------------------
# PWDN (JB1 / V8)
set_property PACKAGE_PIN V8 [get_ports {ov7670_pwdn}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_pwdn}]

# DATA[0] (JB2 / W8)
set_property PACKAGE_PIN W8 [get_ports {ov7670_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[0]}]

# DATA[2] (JB3 / U7)
set_property PACKAGE_PIN U7 [get_ports {ov7670_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[2]}]

# DATA[4] (JB4 / V7)
set_property PACKAGE_PIN V7 [get_ports {ov7670_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[4]}]

# RESET (JB7 / Y7)
set_property PACKAGE_PIN Y7 [get_ports {ov7670_reset}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_reset}]

# DATA[1] (JB8 / Y6)
set_property PACKAGE_PIN Y6 [get_ports {ov7670_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[1]}]

# DATA[3] (JB9 / V6)
set_property PACKAGE_PIN V6 [get_ports {ov7670_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[3]}]

# DATA[5] (JB10 / W6)
set_property PACKAGE_PIN W6 [get_ports {ov7670_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[5]}]

# DATA[6] (JC1 / V15)
set_property PACKAGE_PIN V15 [get_ports {ov7670_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[6]}]

# XCLK (JC2 / W15) - Output to Camera
set_property PACKAGE_PIN W15 [get_ports {ov7670_xclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_xclk}]

# HREF (JC3 / T11)
set_property PACKAGE_PIN T11 [get_ports {ov7670_href}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_href}]

# SIOD (JC4 / T10) - I2C Data
set_property PACKAGE_PIN T10 [get_ports {ov7670_sio_d}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_sio_d}]
set_property PULLUP TRUE [get_ports {ov7670_sio_d}]

# DATA[7] (JC7 / W14)
set_property PACKAGE_PIN W14 [get_ports {ov7670_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[7]}]

# PCLK (JC8 / Y14) - Input from Camera
set_property PACKAGE_PIN Y14 [get_ports {ov7670_pclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_pclk}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports ov7670_pclk]]

# VSYNC (JC9 / T12)
set_property PACKAGE_PIN T12 [get_ports {ov7670_vsync}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_vsync}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports ov7670_vsync]]

# SIOC (JC10 / U12) - I2C Clock
set_property PACKAGE_PIN U12 [get_ports {ov7670_sio_c}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_sio_c}]

## [기존 코드 아래에 추가] 
## VSYNC와 PCLK 모두 일반 핀을 클럭처럼 사용할 수 있도록 허용
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports ov7670_pclk]]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports ov7670_vsync]]