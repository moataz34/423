# EECE 423 Project #1: AXI-Lite SPI Master for ADXL345 Accelerometer

Complete implementation of a digital level using custom AXI-Lite SPI Master IP block.

## Quick Start

### Files Generated

All necessary files have been created in the repository:

```
/home/user/423/
├── hdl/                              ← Verilog hardware files
│   ├── spi_internal.v
│   ├── spi_accelerometer_v1_0_S00_AXI.v
│   └── spi_accelerometer_v1_0.v
├── constraints/                      ← FPGA pin constraints
│   └── spi_accelerometer_constraints.xdc
├── software/                         ← C driver and application
│   ├── spi_accelerometer.h
│   ├── spi_accelerometer.c
│   └── main.c
└── PROJECT_REPORT.md                 ← Detailed documentation
```

## Where to Put Each File

### In Vivado (Hardware):

1. **Create Custom IP Block:**
   ```
   Tools → Create and Package New IP → Create a new AXI4 peripheral
   ```

   Place the Verilog files:
   - `hdl/spi_internal.v` → Add as source file in IP
   - `hdl/spi_accelerometer_v1_0_S00_AXI.v` → Replace default AXI file
   - `hdl/spi_accelerometer_v1_0.v` → Replace top-level module

2. **Add Constraints:**
   ```
   Right-click in Sources → Add Sources → Add or create constraints
   ```
   - Add `constraints/spi_accelerometer_constraints.xdc`

3. **In Block Design:**
   - Add your custom SPI Accel IP
   - Add AXI Timer IP
   - Connect to ZYNQ PS via AXI Interconnect
   - Right-click on SPI signals → Make External

### In Vitis/SDK (Software):

1. **Create Application Project**

2. **Add Files to `src/` folder:**
   ```
   YourProject/src/
   ├── spi_accelerometer.h          ← Copy from software/
   ├── spi_accelerometer.c          ← Copy from software/
   └── main.c               ← Copy from software/
   ```

3. **Update Base Address:**
   - Open `xparameters.h` (auto-generated)
   - Find `XPAR_SPI_ACCELEROMETER_0_S00_AXI_BASEADDR`
   - Update this in `main.c` if name differs

## Hardware Setup

1. **Connect PmodACL to ZedBoard:**
   - Use Pmod connector **JA1** (top row)
   - PmodACL with **jumpers and IC facing UP**
   - Align Pin 1 to Pin 1

2. **Pin Mapping (automatically configured by constraints file):**
   ```
   JA1 (Pin 1) → SPI Clock    (Y11)
   JA2 (Pin 2) → SPI MOSI     (AA11)
   JA3 (Pin 3) → SPI MISO     (Y10)
   JA4 (Pin 4) → SPI CS       (AA9)
   ```

## Building the Project

### Hardware (Vivado):
```bash
1. Create block design
2. Add ZYNQ7, AXI Timer, and custom SPI Accel IP
3. Run Connection Automation
4. Make SPI signals external
5. Generate bitstream
6. Export hardware (include bitstream)
```

### Software (Vitis/SDK):
```bash
1. Create platform project from exported XSA
2. Create application project
3. Add source files (spi_accelerometer.h, spi_accelerometer.c, main.c)
4. Build project
5. Program FPGA and run
```

## Expected Output

When running, you should see on serial terminal (115200 baud):

```
====================================
 EECE 423 - Digital Level
 ADXL345 Accelerometer
====================================

Initializing ADXL345...
ADXL345 initialized successfully.
Device ID: 0xE5 (Expected: 0xE5)

Initializing Timer...
Setting up interrupts...
Starting timer (500ms interval)...

====================================
 Digital Level Active
 Reading Y-Z Plane Inclination
====================================

Accel: X=0 Y=5 Z=255 | G-Force: X=0.000 Y=0.040 Z=2.040 | Inclination: 1.12°
Accel: X=1 Y=3 Z=256 | G-Force: X=0.008 Y=0.024 Z=2.048 | Inclination: 0.67°
...
```

## Testing Checklist

- [ ] Device ID reads as 0xE5
- [ ] When board is flat: Z ≈ 1g, X ≈ 0g, Y ≈ 0g, Angle ≈ 0°
- [ ] When tilted: Angle changes appropriately
- [ ] Updates occur every 500ms
- [ ] No communication errors

## Deliverables for Submission

Upload these files to Moodle:

1. ✅ `spi_accelerometer_v1_0.v` (top-level module)
2. ✅ `spi_accelerometer_v1_0_S00_AXI.v` (AXI interface with register comments)
3. ✅ `spi_accelerometer.h` (driver header)
4. ✅ `spi_accelerometer.c` (driver implementation)
5. ✅ `main.c` (application program)
6. ✅ `PROJECT_REPORT.md` (project report with block diagrams)

Additional files (not required but useful):
- `spi_internal.v` (core SPI module)
- `spi_accelerometer_constraints.xdc` (pin constraints)

## Key Design Features

### Hardware:
- ✅ SPI Mode 3 (CPOL=1, CPHA=1) for ADXL345
- ✅ 4 MHz SPI clock (100 MHz / 25)
- ✅ Multi-byte transfer support (up to 16 bytes)
- ✅ AXI4-Lite compliant interface
- ✅ Proper timing and ready/valid handshaking

### Software:
- ✅ Robust error handling
- ✅ Device ID verification
- ✅ Proper ADXL345 initialization sequence
- ✅ Multi-byte burst reads for efficiency
- ✅ Timer interrupts at 500ms intervals
- ✅ Accurate inclination calculation using atan2

## Troubleshooting

**Problem:** Device ID reads wrong value
- Check Pmod connections
- Verify constraints file is applied
- Check SPI mode configuration (must be Mode 3)

**Problem:** No data updates
- Check timer interrupt setup
- Verify GIC configuration
- Check interrupt priorities

**Problem:** Incorrect angles
- Verify ±4g range configuration
- Check scale factor (0.008 g/LSB)
- Ensure signed 16-bit interpretation

**Problem:** Build errors
- Update base addresses in main.c
- Check include paths
- Verify BSP configuration

## Additional Resources

- Full documentation: `PROJECT_REPORT.md`
- ADXL345 Datasheet: https://www.analog.com/en/products/adxl345.html
- PmodACL Reference: https://reference.digilentinc.com/reference/pmod/pmodacl/
- ZedBoard Docs: https://www.xilinx.com/support/university/xup-boards/XUPZedBoard.html

## Contact

For issues or questions, refer to project documentation or consult course staff.

---

**Project:** EECE 423 - Reconfigurable Computing
**Institution:** American University of Beirut
**Deadline:** November 7, 2025, 11:59 PM
