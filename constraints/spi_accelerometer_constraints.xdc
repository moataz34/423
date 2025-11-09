####################################################################################
## Constraints file for SPI Accelerometer on ZedBoard Pmod JA1
## American University of Beirut - EECE 423
##
## Pmod JA1 Connector Pin Assignments
## The PmodACL should be connected to JA1 with jumpers and IC facing upward
####################################################################################

## SPI Clock - JA1 Pin 1 (Y11)
set_property PACKAGE_PIN Y11 [get_ports o_SPI_Clk]
set_property IOSTANDARD LVCMOS33 [get_ports o_SPI_Clk]

## SPI MOSI (Master Out Slave In) - JA1 Pin 2 (AA11)
set_property PACKAGE_PIN AA11 [get_ports o_SPI_MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports o_SPI_MOSI]

## SPI MISO (Master In Slave Out) - JA1 Pin 3 (Y10)
set_property PACKAGE_PIN Y10 [get_ports i_SPI_MISO]
set_property IOSTANDARD LVCMOS33 [get_ports i_SPI_MISO]

## SPI Chip Select (active low) - JA1 Pin 4 (AA9)
set_property PACKAGE_PIN AA9 [get_ports o_SPI_CS_n]
set_property IOSTANDARD LVCMOS33 [get_ports o_SPI_CS_n]

####################################################################################
## Additional timing constraints
####################################################################################

## Create a clock constraint for the SPI clock (4 MHz)
## Note: This is generated internally, so we don't create a primary clock constraint
## The SPI clock is derived from the 100 MHz system clock

## Set false path for asynchronous reset if needed
## set_false_path -from [get_ports s00_axi_aresetn]
