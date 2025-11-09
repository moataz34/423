/******************************************************************************
 * File: spi_accelerometer.h
 * Description: Driver header for AXI-Lite SPI Master interfacing with ADXL345
 * Author: EECE 423 Project
 * Institution: American University of Beirut
 ******************************************************************************/

#ifndef SPI_ACCELEROMETER_H
#define SPI_ACCELEROMETER_H

#include "xil_types.h"
#include "xil_io.h"

/*****************************************************************************
 * AXI-Lite Register Offsets
 *****************************************************************************/
#define SPI_ACCELEROMETER_CONTROL_REG_OFFSET    0x00  // Control register
#define SPI_ACCELEROMETER_TX_COUNT_REG_OFFSET   0x04  // TX count register
#define SPI_ACCELEROMETER_TX_DATA_REG_OFFSET    0x08  // TX data register
#define SPI_ACCELEROMETER_STATUS_REG_OFFSET     0x0C  // Status register
#define SPI_ACCELEROMETER_RX_COUNT_REG_OFFSET   0x10  // RX count register
#define SPI_ACCELEROMETER_RX_DATA_REG_OFFSET    0x14  // RX data register

/*****************************************************************************
 * Control Register Bit Fields
 * [1:0]   - SPI Mode (CPOL, CPHA)
 * [17:2]  - Clock Scale (16 bits)
 * [20:18] - CS Inactive Clocks (3 bits)
 *****************************************************************************/
#define SPI_MODE_SHIFT              0
#define SPI_MODE_MASK               0x00000003
#define CLK_SCALE_SHIFT             2
#define CLK_SCALE_MASK              0x0003FFFC
#define CS_INACTIVE_SHIFT           18
#define CS_INACTIVE_MASK            0x001C0000

/*****************************************************************************
 * Status Register Bit Fields
 * [0] - TX Ready
 * [1] - RX Data Valid
 *****************************************************************************/
#define STATUS_TX_READY_MASK        0x00000001
#define STATUS_RX_DV_MASK           0x00000002

/*****************************************************************************
 * SPI Mode Definitions (CPOL, CPHA)
 *****************************************************************************/
#define SPI_MODE_0                  0x00  // CPOL=0, CPHA=0
#define SPI_MODE_1                  0x01  // CPOL=0, CPHA=1
#define SPI_MODE_2                  0x02  // CPOL=1, CPHA=0
#define SPI_MODE_3                  0x03  // CPOL=1, CPHA=1 (ADXL345 uses this)

/*****************************************************************************
 * ADXL345 Register Addresses
 *****************************************************************************/
#define ADXL345_DEVID               0x00  // Device ID (should read 0xE5)
#define ADXL345_THRESH_TAP          0x1D
#define ADXL345_OFSX                0x1E
#define ADXL345_OFSY                0x1F
#define ADXL345_OFSZ                0x20
#define ADXL345_DUR                 0x21
#define ADXL345_LATENT              0x22
#define ADXL345_WINDOW              0x23
#define ADXL345_THRESH_ACT          0x24
#define ADXL345_THRESH_INACT        0x25
#define ADXL345_TIME_INACT          0x26
#define ADXL345_ACT_INACT_CTL       0x27
#define ADXL345_THRESH_FF           0x28
#define ADXL345_TIME_FF             0x29
#define ADXL345_TAP_AXES            0x2A
#define ADXL345_ACT_TAP_STATUS      0x2B
#define ADXL345_BW_RATE             0x2C
#define ADXL345_POWER_CTL           0x2D
#define ADXL345_INT_ENABLE          0x2E
#define ADXL345_INT_MAP             0x2F
#define ADXL345_INT_SOURCE          0x30
#define ADXL345_DATA_FORMAT         0x31
#define ADXL345_DATAX0              0x32  // X-axis data LSB
#define ADXL345_DATAX1              0x33  // X-axis data MSB
#define ADXL345_DATAY0              0x34  // Y-axis data LSB
#define ADXL345_DATAY1              0x35  // Y-axis data MSB
#define ADXL345_DATAZ0              0x36  // Z-axis data LSB
#define ADXL345_DATAZ1              0x37  // Z-axis data MSB
#define ADXL345_FIFO_CTL            0x38
#define ADXL345_FIFO_STATUS         0x39

/*****************************************************************************
 * ADXL345 Register Values
 *****************************************************************************/
#define ADXL345_DEVICE_ID_VALUE     0xE5  // Expected device ID
#define ADXL345_POWER_CTL_MEASURE   0x08  // Enable measurement mode
#define ADXL345_DATA_FORMAT_4G      0x09  // ±4g range, 11-bit resolution

/*****************************************************************************
 * ADXL345 SPI Command Format
 * Bit 7: R/W (1=Read, 0=Write)
 * Bit 6: MB (Multi-byte)
 * Bits 5-0: Register Address
 *****************************************************************************/
#define ADXL345_SPI_READ            0x80  // Read bit
#define ADXL345_SPI_WRITE           0x00  // Write bit
#define ADXL345_SPI_MULTIBYTE       0x40  // Multi-byte bit

/*****************************************************************************
 * Configuration Constants
 *****************************************************************************/
#define SPI_CLK_SCALE_4MHZ          25    // 100MHz / 25 = 4MHz
#define SPI_CS_INACTIVE_CLKS        1     // Minimum cycles between transfers

/*****************************************************************************
 * Data Structures
 *****************************************************************************/
typedef struct {
    s16 x;  // X-axis acceleration (signed 16-bit)
    s16 y;  // Y-axis acceleration (signed 16-bit)
    s16 z;  // Z-axis acceleration (signed 16-bit)
} AccelData;

/*****************************************************************************
 * Function Prototypes
 *****************************************************************************/

/**
 * Initialize the SPI controller
 * @param base_addr: Base address of the SPI controller
 */
void SPI_Init(u32 base_addr);

/**
 * Write a single byte to a SPI slave register
 * @param base_addr: Base address of the SPI controller
 * @param reg_addr: Register address
 * @param data: Data byte to write
 */
void SPI_WriteByte(u32 base_addr, u8 reg_addr, u8 data);

/**
 * Read a single byte from a SPI slave register
 * @param base_addr: Base address of the SPI controller
 * @param reg_addr: Register address
 * @return: Data byte read
 */
u8 SPI_ReadByte(u32 base_addr, u8 reg_addr);

/**
 * Read multiple bytes from consecutive SPI slave registers
 * @param base_addr: Base address of the SPI controller
 * @param reg_addr: Starting register address
 * @param data: Pointer to buffer for received data
 * @param count: Number of bytes to read
 */
void SPI_ReadMultiBytes(u32 base_addr, u8 reg_addr, u8 *data, u8 count);

/**
 * Initialize the ADXL345 accelerometer
 * @param base_addr: Base address of the SPI controller
 * @return: 0 on success, -1 on failure
 */
int ADXL345_Init(u32 base_addr);

/**
 * Read the ADXL345 device ID
 * @param base_addr: Base address of the SPI controller
 * @return: Device ID (should be 0xE5)
 */
u8 ADXL345_ReadDeviceID(u32 base_addr);

/**
 * Read acceleration data from all three axes
 * @param base_addr: Base address of the SPI controller
 * @param accel_data: Pointer to AccelData structure
 */
void ADXL345_ReadAccel(u32 base_addr, AccelData *accel_data);

/**
 * Convert raw acceleration data to g-force (±4g range)
 * @param raw_value: Raw 16-bit signed value from ADXL345
 * @return: Acceleration in g (as floating point)
 */
float ADXL345_ConvertToG(s16 raw_value);

/**
 * Wait for TX ready status
 * @param base_addr: Base address of the SPI controller
 */
void SPI_WaitTxReady(u32 base_addr);

#endif // SPI_ACCELEROMETER_H
