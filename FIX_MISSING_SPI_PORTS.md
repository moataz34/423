# Fix for Missing SPI Ports Error

## Problem

When generating the bitstream, Vivado shows these warnings:

```
WARNING: [Vivado 12-584] No ports matched 'o_SPI_Clk'
WARNING: [Vivado 12-584] No ports matched 'o_SPI_MOSI'
WARNING: [Vivado 12-584] No ports matched 'i_SPI_MISO'
WARNING: [Vivado 12-584] No ports matched 'o_SPI_CS_n'
```

This happens because the SPI pins from the custom IP are **not exposed as external ports** in the block design wrapper.

## Root Cause

The SPI Master AXI IP has these ports defined:
- `o_SPI_Clk` - SPI Clock output
- `o_SPI_MOSI` - Master Out Slave In output
- `i_SPI_MISO` - Master In Slave Out input
- `o_SPI_CS_n` - Chip Select output (active low)

However, when you add the IP to a block design, these ports are **internal** to the block design by default. They need to be explicitly **made external** so they appear in the top-level wrapper (`design_1_wrapper.v`).

Without making them external, the constraint file (`zedboard_pmod_ja1.xdc`) cannot find these port names, resulting in the warnings.

## Solution

There are two ways to fix this:

### Option 1: Use the Automated Project Creation Script (RECOMMENDED)

This script will create a complete Vivado project with everything properly configured:

```tcl
# Step 1: Package the IP first
cd /path/to/423
source package_ip.tcl

# Step 2: Create the complete project with SPI ports exposed
source create_vivado_project.tcl

# Step 3: Build the project
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -jobs 4 -to_step write_bitstream
wait_on_run impl_1
```

The script automatically:
- Creates the Zynq Processing System
- Adds AXI interconnect
- Adds AXI Timer for interrupts
- Adds your SPI Master AXI IP
- **Makes all SPI ports external** (the key fix!)
- Adds the constraint file
- Assigns memory addresses

### Option 2: Fix Existing Block Design Manually

If you already have a block design:

1. Open your Vivado project
2. Open the block design (`design_1.bd`)
3. Find the `spi_accelerometer_0` IP block
4. For each SPI port, do the following:
   - Right-click on the port pin → **Make External**
   - Repeat for:
     - `o_SPI_Clk`
     - `i_SPI_MISO`
     - `o_SPI_MOSI`
     - `o_SPI_CS_n`
5. The ports will appear as external connections (small squares on the block)
6. Validate the design (F6)
7. Save the design
8. Regenerate the HDL wrapper:
   - Right-click on `design_1` → **Create HDL Wrapper**
   - Select "Let Vivado manage wrapper and auto-update"
9. Re-run synthesis and implementation

## Verification

After making the ports external, check the generated wrapper file:

**File:** `project.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v`

It should contain these port declarations:

```verilog
module design_1_wrapper
   (
    // ... other ports ...
    i_SPI_MISO,
    o_SPI_CS_n,
    o_SPI_Clk,
    o_SPI_MOSI
   );

input i_SPI_MISO;
output o_SPI_CS_n;
output o_SPI_Clk;
output o_SPI_MOSI;
```

Now the constraint file can successfully bind these ports to physical pins!

## Why This Happens

When Vivado generates a block design:
1. The IP's ports are connected **within** the block design
2. Only ports that cross the block design boundary appear in the wrapper
3. Making a port "external" creates that boundary crossing
4. The wrapper then includes those ports in its port list
5. The constraint file can then reference these ports by name

## Testing the Fix

After regenerating the bitstream:

1. Check the synthesis report - the warnings should be gone
2. Look for these lines in the synthesis output:
   ```
   |6     |IBUF                          |     1|  <- This is i_SPI_MISO
   |7     |OBUF                          |     3|  <- These are o_SPI_Clk, o_SPI_MOSI, o_SPI_CS_n
   ```
3. The implementation should complete successfully
4. The bitstream file (`.bit`) should be generated

## Additional Notes

- The constraint file (`zedboard_pmod_ja1.xdc`) is correct and doesn't need changes
- The HDL code (`spi_master_axi_v1_0.v`) is correct and doesn't need changes
- The issue is purely in the block design configuration
- This is a common mistake when using custom IP in Vivado

## Quick Command Reference

```bash
# Full build from scratch
cd /home/user/423

# Package IP
vivado -mode batch -source package_ip.tcl

# Create project with proper configuration
vivado -mode batch -source create_vivado_project.tcl

# Or open GUI to inspect
vivado vivado_project/spi_accelerometer_project/spi_accelerometer_project.xpr
```
