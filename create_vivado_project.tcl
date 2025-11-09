# TCL Script to Create Complete Vivado Project with SPI Ports Exposed
# This script creates a complete Vivado project with block design
# Run this in Vivado TCL console after packaging the IP

# Configuration
set proj_name "spi_accelerometer_project"
set proj_dir [file normalize [file dirname [info script]]]/vivado_project
set ip_repo_path [file normalize [file dirname [info script]]]/ip_repo
set constraints_file [file normalize [file dirname [info script]]]/constraints/zedboard_pmod_ja1.xdc
set part_name "xc7z020clg484-1"

# Create project directory if it doesn't exist
file mkdir $proj_dir

# Create Vivado project
create_project $proj_name $proj_dir -part $part_name -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Set IP repository paths
set_property ip_repo_paths $ip_repo_path [current_project]
update_ip_catalog -rebuild

# Create block design
create_bd_design "design_1"

# Add Processing System (Zynq)
puts "Adding Zynq Processing System..."
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Configure Zynq
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" } [get_bd_cells processing_system7_0]

# Enable M_AXI_GP0 interface for AXI communication
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1}] [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0}] [get_bd_cells processing_system7_0]

# Enable interrupts
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells processing_system7_0]

# Add AXI Interconnect
puts "Adding AXI SmartConnect..."
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] [get_bd_cells axi_smc]

# Add Reset block
puts "Adding Reset block..."
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50M

# Add AXI Timer for periodic interrupts
puts "Adding AXI Timer..."
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0

# Add SPI Master AXI IP
puts "Adding SPI Master AXI IP..."
create_bd_cell -type ip -vlnv user.org:user:spi_master_axi:1.0 spi_accelerometer_0

# Connect clocks and resets
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_ps7_0_50M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_50M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_smc/aresetn]

# Connect Zynq to AXI Interconnect
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_smc/S00_AXI]

# Connect AXI Interconnect to SPI Master
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins spi_accelerometer_0/S00_AXI]

# Connect AXI Interconnect to Timer
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]

# Connect clocks to AXI SmartConnect
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_smc/aclk]

# Connect clocks to SPI Master
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins spi_accelerometer_0/s00_axi_aclk]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins spi_accelerometer_0/s00_axi_aresetn]

# Connect clocks to Timer
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn]

# Connect timer interrupt
connect_bd_net [get_bd_pins axi_timer_0/interrupt] [get_bd_pins processing_system7_0/IRQ_F2P]

# **CRITICAL: Make SPI ports external - THIS IS THE FIX!**
puts "Making SPI ports external..."
create_bd_port -dir O o_SPI_Clk
connect_bd_net [get_bd_pins spi_accelerometer_0/o_SPI_Clk] [get_bd_ports o_SPI_Clk]

create_bd_port -dir I i_SPI_MISO
connect_bd_net [get_bd_pins spi_accelerometer_0/i_SPI_MISO] [get_bd_ports i_SPI_MISO]

create_bd_port -dir O o_SPI_MOSI
connect_bd_net [get_bd_pins spi_accelerometer_0/o_SPI_MOSI] [get_bd_ports o_SPI_MOSI]

create_bd_port -dir O o_SPI_CS_n
connect_bd_net [get_bd_pins spi_accelerometer_0/o_SPI_CS_n] [get_bd_ports o_SPI_CS_n]

# Assign addresses
assign_bd_address
set_property offset 0x43C00000 [get_bd_addr_segs {processing_system7_0/Data/SEG_spi_accelerometer_0_S00_AXI_reg}]
set_property range 64K [get_bd_addr_segs {processing_system7_0/Data/SEG_spi_accelerometer_0_S00_AXI_reg}]
set_property offset 0x42800000 [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_timer_0_Reg}]

# Validate design
validate_bd_design

# Save block design
save_bd_design

# Generate HDL wrapper
puts "Generating HDL wrapper..."
make_wrapper -files [get_files ${proj_dir}/${proj_name}.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v

# Add constraints file
puts "Adding constraints file..."
add_files -fileset constrs_1 -norecurse $constraints_file

# Set top module
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "\n****************************************************"
puts "Vivado Project Created Successfully!"
puts "Project Location: $proj_dir/$proj_name"
puts ""
puts "SPI Ports have been exposed as external:"
puts "  - o_SPI_Clk"
puts "  - i_SPI_MISO"
puts "  - o_SPI_MOSI"
puts "  - o_SPI_CS_n"
puts ""
puts "Constraint file has been added:"
puts "  - $constraints_file"
puts ""
puts "Next steps:"
puts "  1. Run Synthesis: launch_runs synth_1 -jobs 4"
puts "  2. Run Implementation: launch_runs impl_1 -jobs 4 -to_step write_bitstream"
puts "  3. Wait for completion: wait_on_run impl_1"
puts "****************************************************\n"
