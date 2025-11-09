##########################################################################################
# ZedBoard Pin Constraints for PmodACL on JA1 Connector
#
# This constraints file maps the SPI interface signals to the physical pins
# of the Zedboard's JA1 Pmod connector.
#
# PmodACL Connection (with IC facing up):
# Pin 1 (Y11)  - CS   (Chip Select)
# Pin 2 (AA11) - MOSI (Master Out Slave In)
# Pin 3 (Y10)  - MISO (Master In Slave Out)
# Pin 4 (AA9)  - SCK  (Serial Clock)
# Pins 5,11    - GND
# Pins 6,12    - VCC
#
# Reference: ZedBoard Hardware User's Guide (UG925)
##########################################################################################

# SPI Chip Select (CS) - JA1 Pin 1
set_property PACKAGE_PIN Y11 [get_ports o_SPI_CS_n]
set_property IOSTANDARD LVCMOS33 [get_ports o_SPI_CS_n]

# SPI Master Out Slave In (MOSI) - JA1 Pin 2
set_property PACKAGE_PIN AA11 [get_ports o_SPI_MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports o_SPI_MOSI]

# SPI Master In Slave Out (MISO) - JA1 Pin 3
set_property PACKAGE_PIN Y10 [get_ports i_SPI_MISO]
set_property IOSTANDARD LVCMOS33 [get_ports i_SPI_MISO]

# SPI Serial Clock (SCK/SCLK) - JA1 Pin 4
set_property PACKAGE_PIN AA9 [get_ports o_SPI_Clk]
set_property IOSTANDARD LVCMOS33 [get_ports o_SPI_Clk]

# Optional: Add timing constraints
# The ADXL345 supports up to 5 MHz SPI clock
# We're using 4 MHz as specified in the project requirements
create_clock -period 250.000 -name spi_clk [get_ports o_SPI_Clk]

# Relax timing on SPI interface since we're running at low frequency (4 MHz)
set_input_delay -clock spi_clk -min 0.000 [get_ports i_SPI_MISO]
set_input_delay -clock spi_clk -max 50.000 [get_ports i_SPI_MISO]
set_output_delay -clock spi_clk -min 0.000 [get_ports {o_SPI_MOSI o_SPI_CS_n}]
set_output_delay -clock spi_clk -max 50.000 [get_ports {o_SPI_MOSI o_SPI_CS_n}]

# Set false path between system clock and SPI clock domains if needed
# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks spi_clk]
# set_false_path -from [get_clocks spi_clk] -to [get_clocks clk_fpga_0]
