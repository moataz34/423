# TCL Script to Package SPI Master AXI IP
# This script creates an IP package from the SPI Master HDL sources
# Run this script in Vivado TCL console: source package_ip.tcl

# Set the project directory
set proj_dir [file normalize [file dirname [info script]]]
set ip_name "spi_master_axi"
set ip_version "1.0"
set vendor "user.org"
set library "user"
set taxonomy "/UserIP"

# Create temporary project for IP packaging
set temp_proj_name "temp_ip_proj"
create_project $temp_proj_name $proj_dir/temp_proj -part xc7z020clg484-1 -force

# Add HDL source files
add_files -norecurse $proj_dir/hdl/spi_master.v
add_files -norecurse $proj_dir/hdl/spi_master_axi_v1_0_S00_AXI.v
add_files -norecurse $proj_dir/hdl/spi_master_axi_v1_0.v

# Update compile order
update_compile_order -fileset sources_1

# Package the IP
ipx::package_project -root_dir $proj_dir/ip_repo/$ip_name -vendor $vendor -library $library -taxonomy $taxonomy -import_files -set_current false

# Open the packaged IP for editing
ipx::edit_ip_in_project -upgrade true -name edit_ip_project -directory $proj_dir/temp_proj/$ip_name $proj_dir/ip_repo/$ip_name/component.xml

# Set IP identification
set core [ipx::current_core]
set_property name $ip_name $core
set_property display_name "AXI-Lite SPI Master" $core
set_property description "AXI-Lite SPI Master for interfacing with SPI slave devices like ADXL345 accelerometer" $core
set_property version $ip_version $core
set_property vendor_display_name "User Organization" $core
set_property company_url "http://www.example.com" $core

# Associate AXI interface
ipx::associate_bus_interfaces -busif S00_AXI -clock s00_axi_aclk $core

# Mark SPI ports as external
set_property display_name "SPI Clock" [ipx::get_ports o_SPI_Clk -of_objects $core]
set_property display_name "SPI MISO" [ipx::get_ports i_SPI_MISO -of_objects $core]
set_property display_name "SPI MOSI" [ipx::get_ports o_SPI_MOSI -of_objects $core]
set_property display_name "SPI Chip Select" [ipx::get_ports o_SPI_CS_n -of_objects $core]

# Add descriptions to SPI ports
set_property description "SPI Serial Clock output" [ipx::get_ports o_SPI_Clk -of_objects $core]
set_property description "SPI Master In Slave Out input" [ipx::get_ports i_SPI_MISO -of_objects $core]
set_property description "SPI Master Out Slave In output" [ipx::get_ports o_SPI_MOSI -of_objects $core]
set_property description "SPI Chip Select output (active low)" [ipx::get_ports o_SPI_CS_n -of_objects $core]

# Create SPI interface
ipx::add_bus_interface SPI $core
set_property abstraction_type_vlnv xilinx.com:interface:spi_rtl:1.0 [ipx::get_bus_interfaces SPI -of_objects $core]
set_property bus_type_vlnv xilinx.com:interface:spi:1.0 [ipx::get_bus_interfaces SPI -of_objects $core]
set_property interface_mode master [ipx::get_bus_interfaces SPI -of_objects $core]
ipx::add_port_map SS_O [ipx::get_bus_interfaces SPI -of_objects $core]
set_property physical_name o_SPI_CS_n [ipx::get_port_maps SS_O -of_objects [ipx::get_bus_interfaces SPI -of_objects $core]]
ipx::add_port_map IO0_O [ipx::get_bus_interfaces SPI -of_objects $core]
set_property physical_name o_SPI_MOSI [ipx::get_port_maps IO0_O -of_objects [ipx::get_bus_interfaces SPI -of_objects $core]]
ipx::add_port_map IO1_I [ipx::get_bus_interfaces SPI -of_objects $core]
set_property physical_name i_SPI_MISO [ipx::get_port_maps IO1_I -of_objects [ipx::get_bus_interfaces SPI -of_objects $core]]
ipx::add_port_map SCK_O [ipx::get_bus_interfaces SPI -of_objects $core]
set_property physical_name o_SPI_Clk [ipx::get_port_maps SCK_O -of_objects [ipx::get_bus_interfaces SPI -of_objects $core]]

# Set supported FPGA families
set_property supported_families {zynq Production} $core

# Save and close
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

# Close the IP project
close_project

# Clean up temporary project
# file delete -force $proj_dir/temp_proj

puts "****************************************************"
puts "IP Packaging Complete!"
puts "IP Location: $proj_dir/ip_repo/$ip_name"
puts "Add this directory to your IP repository in Vivado:"
puts "  Tools -> Settings -> IP -> Repository"
puts "****************************************************"
