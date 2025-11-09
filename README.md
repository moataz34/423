# EECE 423 Project 1: AXI-Lite SPI Master IP Block

This repository contains a complete implementation of an AXI-Lite SPI Master IP block for interfacing with the Digilent PmodACL 3-axis accelerometer on the ZedBoard.

## 📍 Missing SPI Pins - FOUND HERE!

**The SPI pins (MISO, MOSI, and SCK) are defined in THREE places:**

### 1. Top-Level Module (`hdl/spi_master_axi_v1_0.v`)
Lines 24-27 define the SPI interface ports:
```verilog
output wire o_SPI_Clk,          // SPI Clock (SCK)
input  wire i_SPI_MISO,         // SPI Master In Slave Out (MISO)
output wire o_SPI_MOSI,         // SPI Master Out Slave In (MOSI)
output wire o_SPI_CS_n,         // SPI Chip Select (active low)
```

### 2. SPI Master Core (`hdl/spi_master.v`)
Lines 36-39 define the SPI interface:
```verilog
output reg         o_SPI_Clk,            // SPI clock (SCK)
input  wire        i_SPI_MISO,           // SPI MISO
output reg         o_SPI_MOSI,           // SPI MOSI
output reg         o_SPI_CS_n            // SPI chip select (active low)
```

### 3. Constraints File (`constraints/zedboard_pmod_ja1.xdc`)
Lines 18-31 map the SPI signals to physical ZedBoard pins:
```tcl
# CS   - Pin Y11  (JA1 Pin 1)
# MOSI - Pin AA11 (JA1 Pin 2)
# MISO - Pin Y10  (JA1 Pin 3)
# SCK  - Pin AA9  (JA1 Pin 4)
```

## 📁 Project Structure

```
423/
├── hdl/
│   ├── spi_master_axi_v1_0.v           # Top-level module with SPI pins
│   ├── spi_master_axi_v1_0_S00_AXI.v   # AXI-Lite slave interface
│   └── spi_master.v                     # SPI master core logic
├── constraints/
│   └── zedboard_pmod_ja1.xdc            # Pin mappings for JA1 connector
├── src/
│   ├── spi_driver.h                     # Driver header (to be created)
│   └── spi_driver.c                     # Driver implementation (to be created)
├── package_ip.tcl                       # TCL script to package IP
├── project1.pdf                         # Project specification
└── README.md                            # This file
```

## 🔌 Hardware Connections

Connect the PmodACL to ZedBoard JA1 connector with the **IC facing UP**:

| Pmod Pin | Signal | ZedBoard Pin | Function |
|----------|--------|--------------|----------|
| 1        | CS     | Y11          | Chip Select |
| 2        | MOSI   | AA11         | Master Out Slave In |
| 3        | MISO   | Y10          | Master In Slave Out |
| 4        | SCK    | AA9          | Serial Clock |
| 5        | GND    | GND          | Ground |
| 6        | VCC    | 3.3V         | Power |

## 🚀 How to Use This IP

### Step 1: Package the IP in Vivado

1. Open Vivado
2. In the TCL Console, navigate to this directory:
   ```tcl
   cd /path/to/423
   ```
3. Run the packaging script:
   ```tcl
   source package_ip.tcl
   ```
4. Add the IP repository:
   - Go to **Tools → Settings → IP → Repository**
   - Click the **+** button
   - Add the `ip_repo/spi_master_axi` directory

### Step 2: Create Block Design

1. Create a new Vivado project for ZedBoard (xc7z020clg484-1)
2. Create a Block Design
3. Add Zynq Processing System
4. Add your SPI Master AXI IP from the IP Catalog
5. Add AXI Timer IP (for periodic interrupts)
6. Connect everything through AXI Interconnect
7. **Make SPI ports external**:
   - Right-click on `o_SPI_Clk` → **Make External**
   - Right-click on `i_SPI_MISO` → **Make External**
   - Right-click on `o_SPI_MOSI` → **Make External**
   - Right-click on `o_SPI_CS_n` → **Make External**

### Step 3: Add Constraints

1. Add the constraints file to your project:
   - **Add Sources → Add or Create Constraints**
   - Add `constraints/zedboard_pmod_ja1.xdc`

### Step 4: Generate Bitstream

1. Validate Design
2. Create HDL Wrapper
3. Run Synthesis
4. Run Implementation
5. Generate Bitstream
6. Export Hardware (include bitstream)

## 📝 Register Map

The SPI Master uses AXI-Lite registers to control operations:

| Offset | Name           | Access | Description |
|--------|----------------|--------|-------------|
| 0x00   | CONTROL_REG    | R/W    | [1:0] SPI Mode, [31:16] Clock Scale |
| 0x04   | CONFIG_REG     | R/W    | [2:0] CS Inactive, [12:8] TX Count |
| 0x08   | TX_DATA_REG    | W      | [7:0] Transmit Data |
| 0x0C   | RX_DATA_REG    | R      | [7:0] Received Data |
| 0x10   | STATUS_REG     | R      | [0] TX Ready, [1] RX Valid, [11:8] RX Count |

### Example Configuration

For ADXL345 (4 MHz, Mode 3):
```c
// Set SPI Mode 3 (CPOL=1, CPHA=1) and clock scale to 25 (100MHz/25 = 4MHz)
Xil_Out32(BASEADDR + 0x00, 0x00190003);  // clk_scale=25, mode=3

// Set CS inactive clocks to 1, TX count to 1 byte
Xil_Out32(BASEADDR + 0x04, 0x00000101);
```

## 🔧 Software Development

### Driver Functions to Implement

Create `src/spi_driver.h` and `src/spi_driver.c` with:

```c
// Initialize SPI master
void SPI_Init(u32 BaseAddress, u8 spi_mode, u16 clk_scale);

// Write single byte
void SPI_WriteByte(u32 BaseAddress, u8 data);

// Read single byte
u8 SPI_ReadByte(u32 BaseAddress);

// Write register to ADXL345
void ADXL345_WriteReg(u32 BaseAddress, u8 reg_addr, u8 data);

// Read register from ADXL345
u8 ADXL345_ReadReg(u32 BaseAddress, u8 reg_addr);

// Read multiple registers
void ADXL345_ReadMultiple(u32 BaseAddress, u8 reg_addr, u8* buffer, u8 count);
```

### ADXL345 Initialization Sequence

```c
// Minimal initialization for ±4g range
ADXL345_WriteReg(baseaddr, 0x31, 0x09);  // DATA_FORMAT: ±4g, 11-bit resolution
ADXL345_WriteReg(baseaddr, 0x2D, 0x08);  // POWER_CTL: Start measurements

// Verify device ID
u8 devid = ADXL345_ReadReg(baseaddr, 0x00);  // Should return 0xE5
```

### Reading Acceleration Data

```c
// Read X, Y, Z acceleration (6 bytes starting at 0x32)
u8 accel_data[6];
ADXL345_ReadMultiple(baseaddr, 0x32, accel_data, 6);

// Convert to 16-bit signed values
s16 accel_x = (s16)((accel_data[1] << 8) | accel_data[0]);
s16 accel_y = (s16)((accel_data[3] << 8) | accel_data[2]);
s16 accel_z = (s16)((accel_data[5] << 8) | accel_data[4]);

// Convert to angle in Y-Z plane (for digital level)
float angle = atan2(accel_y, accel_z) * 180.0 / M_PI;
```

## 🧪 Testing

### Test 1: Device ID Read
```c
u8 device_id = ADXL345_ReadReg(baseaddr, 0x00);
xil_printf("Device ID: 0x%02X (expected 0xE5)\n\r", device_id);
```

### Test 2: Digital Level
Display the inclination angle in the Y-Z plane on PuTTY terminal, updated every 500ms via timer interrupt.

## 🐛 Debugging Tips

1. **No response from ADXL345:**
   - Check physical connections
   - Verify SPI mode is set to 3 (CPOL=1, CPHA=1)
   - Verify clock scale (should be 25 for 4 MHz)

2. **Wrong data received:**
   - Check MISO/MOSI aren't swapped
   - Verify constraints file is added to project
   - Check that ports were made external in block design

3. **IP not appearing in Vivado:**
   - Verify IP repository path is correct
   - Refresh IP catalog
   - Check for errors in TCL console

## 📚 References

- [ZedBoard Hardware User's Guide (UG925)](http://www.zedboard.org/sites/default/files/documentations/ZedBoard_HW_UG_v2_2.pdf)
- [Digilent PmodACL Reference Manual](https://reference.digilentinc.com/reference/pmod/pmodacl/reference-manual)
- [ADXL345 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/ADXL345.pdf)
- [AXI Reference Guide (UG761)](https://www.xilinx.com/support/documentation/ip_documentation/axi_ref_guide/latest/ug761_axi_reference_guide.pdf)

## 📅 Deliverables

Upload to Moodle by **11:59 PM, November 7, 2025**:

1. `spi_master_axi_v1_0.v` - Top-level module
2. `spi_master_axi_v1_0_S00_AXI.v` - AXI interface (with register comments)
3. `spi_driver.h` and `spi_driver.c` - Driver files
4. Application `.c` file - Digital level implementation
5. Project report with block diagram

---

## ✅ Summary: Where are MISO, MOSI, and SCK?

**They are in the top-level module (`hdl/spi_master_axi_v1_0.v`) lines 24-27!**

When you package this IP and add it to your block design, these pins will automatically appear in the IP block. You just need to:
1. Right-click each pin
2. Select "Make External"
3. Add the constraints file to map them to physical pins

The pins are **already defined and ready to use**! 🎉
