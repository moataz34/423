# Quick Fix Script for Existing Block Design
# This script makes the SPI ports external in an existing block design
# Run this in the Vivado TCL console with your project already open

# Check if a project is open
if {[current_project -quiet] == ""} {
    puts "ERROR: No project is currently open!"
    puts "Please open your Vivado project first, then run this script."
    return
}

# Check if block design exists
if {[get_files -quiet *.bd] == ""} {
    puts "ERROR: No block design found in the project!"
    puts "Please create a block design first."
    return
}

# Open the block design
set bd_file [get_files *.bd]
open_bd_design $bd_file
puts "Opened block design: $bd_file"

# Find the SPI Master IP instance
set spi_ip [get_bd_cells -quiet -filter {VLNV =~ "*spi_master_axi*"}]

if {$spi_ip == ""} {
    puts "ERROR: SPI Master AXI IP not found in block design!"
    puts "Available cells:"
    puts [get_bd_cells]
    return
}

puts "Found SPI IP: $spi_ip"

# Check if ports already exist
set existing_ports [get_bd_ports -quiet {o_SPI_Clk i_SPI_MISO o_SPI_MOSI o_SPI_CS_n}]
if {$existing_ports != ""} {
    puts "WARNING: Some SPI ports already exist as external ports:"
    puts $existing_ports
    puts "Removing them first..."
    delete_bd_objs $existing_ports
}

# Make SPI Clock external
puts "Making o_SPI_Clk external..."
set spi_clk_pin [get_bd_pins ${spi_ip}/o_SPI_Clk]
if {$spi_clk_pin != ""} {
    create_bd_port -dir O o_SPI_Clk
    connect_bd_net $spi_clk_pin [get_bd_ports o_SPI_Clk]
    puts "  ✓ o_SPI_Clk connected"
} else {
    puts "  ✗ o_SPI_Clk pin not found on IP"
}

# Make SPI MISO external
puts "Making i_SPI_MISO external..."
set spi_miso_pin [get_bd_pins ${spi_ip}/i_SPI_MISO]
if {$spi_miso_pin != ""} {
    create_bd_port -dir I i_SPI_MISO
    connect_bd_net $spi_miso_pin [get_bd_ports i_SPI_MISO]
    puts "  ✓ i_SPI_MISO connected"
} else {
    puts "  ✗ i_SPI_MISO pin not found on IP"
}

# Make SPI MOSI external
puts "Making o_SPI_MOSI external..."
set spi_mosi_pin [get_bd_pins ${spi_ip}/o_SPI_MOSI]
if {$spi_mosi_pin != ""} {
    create_bd_port -dir O o_SPI_MOSI
    connect_bd_net $spi_mosi_pin [get_bd_ports o_SPI_MOSI]
    puts "  ✓ o_SPI_MOSI connected"
} else {
    puts "  ✗ o_SPI_MOSI pin not found on IP"
}

# Make SPI CS external
puts "Making o_SPI_CS_n external..."
set spi_cs_pin [get_bd_pins ${spi_ip}/o_SPI_CS_n]
if {$spi_cs_pin != ""} {
    create_bd_port -dir O o_SPI_CS_n
    connect_bd_net $spi_cs_pin [get_bd_ports o_SPI_CS_n]
    puts "  ✓ o_SPI_CS_n connected"
} else {
    puts "  ✗ o_SPI_CS_n pin not found on IP"
}

# Validate the design
puts "\nValidating block design..."
validate_bd_design

# Save the design
save_bd_design

puts "\n****************************************************"
puts "Block Design Fix Complete!"
puts ""
puts "External SPI ports created:"
set ext_ports [get_bd_ports {o_SPI_Clk i_SPI_MISO o_SPI_MOSI o_SPI_CS_n}]
foreach port $ext_ports {
    set dir [get_property DIR $port]
    puts "  - $port (direction: $dir)"
}
puts ""
puts "Next steps:"
puts "  1. Regenerate HDL wrapper (if not auto-managed)"
puts "  2. Re-run synthesis"
puts "  3. Re-run implementation"
puts "  4. Generate bitstream"
puts "****************************************************\n"

# Check if wrapper needs regeneration
set wrapper_file [get_files -quiet *wrapper.v]
if {$wrapper_file != ""} {
    set wrapper_status [get_property IS_MANAGED $wrapper_file]
    if {$wrapper_status == 0} {
        puts "NOTE: Wrapper is not auto-managed."
        puts "You may need to manually regenerate it:"
        puts "  Right-click design_1 -> Create HDL Wrapper -> Let Vivado manage"
    } else {
        puts "Wrapper is auto-managed and will be updated automatically."
    }
}
