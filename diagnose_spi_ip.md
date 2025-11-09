# SPI IP Core Diagnosis and Fix

## Problem Summary

The SPI IP core at address 0x43C00000 is not responding:
- STATUS register reads 0x00000000 (should read 0x00000001 with TX_READY=1)
- All SPI operations timeout
- Writes succeed but reads return 0

## Root Cause

The IP core is either:
1. **Stuck in reset** - Reset signal not released
2. **Not clocked** - Clock not connected or not running
3. **Not in bitstream** - Hardware not built with latest changes

## Diagnosis Steps

### 1. Check If Hardware Was Built

Look for these files that should exist if hardware was properly built:
```bash
# Vivado project
ls -la vivado_project/spi_accelerometer_project/

# Bitstream
find vivado_project -name "*.bit"

# Hardware export
find vivado_project -name "*.xsa"
```

**If these don't exist**: Hardware was never built → **Solution: Build Hardware** (see below)

### 2. Check If Using Old Bitstream

If hardware files exist, check the timestamps:
```bash
# When was the bitstream built?
find vivado_project -name "*.bit" -ls

# When were the HDL fixes committed?
git log --oneline -5
```

**If bitstream is older than commit a73b5df** ("Fix missing SPI pins"): Using old bitstream → **Solution: Rebuild Hardware**

### 3. Check Block Design Configuration

If you have a Vivado project, open it and verify:
```tcl
# In Vivado TCL console:
open_project vivado_project/spi_accelerometer_project/spi_accelerometer_project.xpr
open_bd_design [get_files *.bd]

# Check if SPI IP exists
get_bd_cells -filter {VLNV =~ "*spi_master_axi*"}
# Should return: spi_accelerometer_0

# Check if reset is connected
get_bd_nets -of_objects [get_bd_pins spi_accelerometer_0/s00_axi_aresetn]
# Should show connection to rst_ps7_0_50M/peripheral_aresetn

# Check if clock is connected
get_bd_nets -of_objects [get_bd_pins spi_accelerometer_0/s00_axi_aclk]
# Should show connection to processing_system7_0/FCLK_CLK0

# Check if SPI ports are external
get_bd_ports {o_SPI_Clk i_SPI_MISO o_SPI_MOSI o_SPI_CS_n}
# Should list all 4 ports
```

## Solution: Build Hardware Properly

### Option 1: Clean Build from Scratch (RECOMMENDED)

This ensures everything is built correctly with all fixes applied:

```bash
cd /home/user/423

# Step 1: Clean any old builds
rm -rf vivado_project temp_proj

# Step 2: Package the IP
vivado -mode tcl <<'EOF'
source package_ip.tcl
exit
EOF

# Step 3: Create complete Vivado project with proper configuration
vivado -mode tcl <<'EOF'
source create_vivado_project.tcl
exit
EOF

# Step 4: Build the hardware
vivado -mode tcl <<'EOF'
open_project vivado_project/spi_accelerometer_project/spi_accelerometer_project.xpr
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -jobs 4 -to_step write_bitstream
wait_on_run impl_1
exit
EOF
```

This will:
- Package the SPI IP with correct port definitions
- Create block design with:
  - Zynq PS
  - AXI Interconnect
  - SPI Master IP (with reset and clock properly connected)
  - AXI Timer
  - **SPI ports made external** (critical fix!)
- Add constraint file for pin mapping
- Build bitstream

### Option 2: Build in Vivado GUI

If you prefer GUI control:

```bash
cd /home/user/423

# Package IP
vivado -mode tcl -source package_ip.tcl

# Create project
vivado -mode tcl -source create_vivado_project.tcl

# Then in Vivado GUI:
# 1. Flow Navigator → Run Synthesis
# 2. Flow Navigator → Run Implementation
# 3. Flow Navigator → Generate Bitstream
```

### Option 3: Fix Existing Project

If you already have a project and just need to fix the SPI ports:

```bash
# Open your existing project
vivado vivado_project/spi_accelerometer_project/spi_accelerometer_project.xpr

# In Vivado TCL Console:
source fix_block_design.tcl

# Then rebuild:
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

## After Building Hardware

### 1. Export Hardware
In Vivado:
- File → Export → Export Hardware
- Include bitstream: ✅ YES
- Save as: `design_1_wrapper.xsa`

### 2. Create Vitis Workspace

```bash
# Create platform project
vitis -workspace vitis_workspace &

# In Vitis GUI:
# 1. Create Platform Project from XSA
# 2. Create Application Project
# 3. Import source files:
#    - src/digital_level_app.c
#    - src/spi_driver.c
#    - src/spi_driver.h
# 4. Build application
# 5. Run on hardware
```

### 3. Verify xparameters.h

After creating the platform, check:
```bash
find vitis_workspace -name "xparameters.h" -exec grep -H "SPI_ACCELEROMETER" {} \;
```

Should show:
```c
#define XPAR_SPI_ACCELEROMETER_0_BASEADDR 0x43C00000
```

### 4. Test the Fix

After programming the FPGA with the new bitstream and running the application, you should see:
```
[DEBUG] Initial STATUS register: 0x00000001
```

Instead of:
```
[DEBUG] Initial STATUS register: 0x00000000  ❌
```

The TX_READY bit (bit 0) should be 1, indicating the SPI core is alive and ready.

## Quick Verification Checklist

After rebuilding, verify:

- [ ] Bitstream generated without "No ports matched" warnings
- [ ] Implementation report shows SPI signals routed to pins
- [ ] XSA file exported with bitstream included
- [ ] xparameters.h contains XPAR_SPI_ACCELEROMETER_0_BASEADDR
- [ ] STATUS register reads 0x00000001 (not 0x00000000)
- [ ] No timeout warnings during SPI communication
- [ ] Device ID reads 0xE5 from ADXL345

## If Problem Persists After Rebuild

If STATUS still reads 0x00000000 after rebuilding:

1. **Verify FPGA is programmed with new bitstream**:
   ```bash
   # Check bitstream timestamp
   ls -l design_1_wrapper.bit
   ```

2. **Check AXI address is correct**:
   - In Vivado: Address Editor → verify SPI IP is at 0x43C00000
   - In software: verify XPAR_SPI_ACCELEROMETER_0_BASEADDR matches

3. **Test AXI bus with simple write/read**:
   ```c
   // Try writing and reading CONTROL register
   Xil_Out32(0x43C00000 + 0x00, 0x12345678);
   u32 readback = Xil_In32(0x43C00000 + 0x00);
   xil_printf("Wrote: 0x12345678, Read: 0x%08X\n", readback);
   ```

   - If readback matches: AXI bus works, issue is in IP core
   - If readback is 0 or wrong: AXI bus issue or wrong address

4. **Add ChipScope/ILA to debug**:
   - Monitor reset and clock signals to SPI IP
   - Verify they toggle correctly

## Expected Timeline

- **IP Packaging**: ~2 minutes
- **Project Creation**: ~3 minutes
- **Synthesis**: ~10 minutes
- **Implementation**: ~15 minutes
- **Bitstream Generation**: ~5 minutes
- **Total**: ~35 minutes

## Next Steps

1. Run the build commands above
2. Verify no warnings about missing ports
3. Export hardware with bitstream
4. Create Vitis workspace
5. Build and run application
6. Confirm STATUS register now reads 0x00000001

The key fix is ensuring the SPI IP is properly integrated into the block design with correct clock, reset, and **external port connections**.
