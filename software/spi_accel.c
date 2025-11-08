/******************************************************************************
 * File: spi_accel.c
 * Description: Driver implementation for AXI-Lite SPI Master with ADXL345
 * Author: EECE 423 Project
 * Institution: American University of Beirut
 ******************************************************************************/

#include "spi_accel.h"
#include "xil_io.h"
#include "sleep.h"
#include <math.h>

/*****************************************************************************
 * Helper Macros for Register Access
 *****************************************************************************/
#define SPI_WriteReg(base, offset, val) \
    Xil_Out32((base) + (offset), (val))

#define SPI_ReadReg(base, offset) \
    Xil_In32((base) + (offset))

/*****************************************************************************
 * Initialize the SPI controller
 *****************************************************************************/
void SPI_Init(u32 base_addr)
{
    u32 control_val;

    // Configure SPI Mode 3 (CPOL=1, CPHA=1) for ADXL345
    // Clock scale = 25 (100 MHz / 25 = 4 MHz)
    // CS inactive clocks = 1
    control_val = (SPI_MODE_3 << SPI_MODE_SHIFT) |
                  (SPI_CLK_SCALE_4MHZ << CLK_SCALE_SHIFT) |
                  (SPI_CS_INACTIVE_CLKS << CS_INACTIVE_SHIFT);

    SPI_WriteReg(base_addr, SPI_ACCEL_CONTROL_REG_OFFSET, control_val);

    // Small delay to ensure configuration is applied
    usleep(1000);
}

/*****************************************************************************
 * Wait for TX ready status
 *****************************************************************************/
void SPI_WaitTxReady(u32 base_addr)
{
    u32 status;
    u32 timeout = 10000;  // Timeout counter

    do {
        status = SPI_ReadReg(base_addr, SPI_ACCEL_STATUS_REG_OFFSET);
        timeout--;
        if (timeout == 0) {
            // Timeout occurred - this should not happen in normal operation
            break;
        }
    } while (!(status & STATUS_TX_READY_MASK));
}

/*****************************************************************************
 * Write a single byte to a SPI slave register
 *****************************************************************************/
void SPI_WriteByte(u32 base_addr, u8 reg_addr, u8 data)
{
    u8 cmd_byte;

    // Set transfer count to 2 bytes (command + data)
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_COUNT_REG_OFFSET, 2);

    // Wait for TX ready
    SPI_WaitTxReady(base_addr);

    // Send command byte (Write, Single-byte, Register Address)
    cmd_byte = ADXL345_SPI_WRITE | (reg_addr & 0x3F);
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_DATA_REG_OFFSET, cmd_byte);

    // Wait for TX ready
    SPI_WaitTxReady(base_addr);

    // Send data byte
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_DATA_REG_OFFSET, data);

    // Wait for transfer to complete
    SPI_WaitTxReady(base_addr);

    // Small delay between transactions
    usleep(10);
}

/*****************************************************************************
 * Read a single byte from a SPI slave register
 *****************************************************************************/
u8 SPI_ReadByte(u32 base_addr, u8 reg_addr)
{
    u8 cmd_byte;
    u8 rx_data;
    u32 status;
    u32 timeout;

    // Set transfer count to 2 bytes (command + dummy/data)
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_COUNT_REG_OFFSET, 2);

    // Wait for TX ready
    SPI_WaitTxReady(base_addr);

    // Send command byte (Read, Single-byte, Register Address)
    cmd_byte = ADXL345_SPI_READ | (reg_addr & 0x3F);
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_DATA_REG_OFFSET, cmd_byte);

    // Wait for TX ready
    SPI_WaitTxReady(base_addr);

    // Send dummy byte to clock in data
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_DATA_REG_OFFSET, 0x00);

    // Wait for RX data valid
    timeout = 10000;
    do {
        status = SPI_ReadReg(base_addr, SPI_ACCEL_STATUS_REG_OFFSET);
        timeout--;
        if (timeout == 0) break;
    } while (!(status & STATUS_RX_DV_MASK));

    // Read received data
    rx_data = SPI_ReadReg(base_addr, SPI_ACCEL_RX_DATA_REG_OFFSET) & 0xFF;

    // Wait for transfer to complete
    SPI_WaitTxReady(base_addr);

    // Small delay between transactions
    usleep(10);

    return rx_data;
}

/*****************************************************************************
 * Read multiple bytes from consecutive SPI slave registers
 *****************************************************************************/
void SPI_ReadMultiBytes(u32 base_addr, u8 reg_addr, u8 *data, u8 count)
{
    u8 cmd_byte;
    u32 status;
    u32 timeout;
    u8 i;

    // Set transfer count (command byte + data bytes)
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_COUNT_REG_OFFSET, count + 1);

    // Wait for TX ready
    SPI_WaitTxReady(base_addr);

    // Send command byte (Read, Multi-byte, Register Address)
    cmd_byte = ADXL345_SPI_READ | ADXL345_SPI_MULTIBYTE | (reg_addr & 0x3F);
    SPI_WriteReg(base_addr, SPI_ACCEL_TX_DATA_REG_OFFSET, cmd_byte);

    // Send dummy bytes and receive data
    for (i = 0; i < count; i++) {
        // Wait for TX ready
        SPI_WaitTxReady(base_addr);

        // Send dummy byte
        SPI_WriteReg(base_addr, SPI_ACCEL_TX_DATA_REG_OFFSET, 0x00);

        // Wait for RX data valid
        timeout = 10000;
        do {
            status = SPI_ReadReg(base_addr, SPI_ACCEL_STATUS_REG_OFFSET);
            timeout--;
            if (timeout == 0) break;
        } while (!(status & STATUS_RX_DV_MASK));

        // Read received data
        data[i] = SPI_ReadReg(base_addr, SPI_ACCEL_RX_DATA_REG_OFFSET) & 0xFF;
    }

    // Wait for transfer to complete
    SPI_WaitTxReady(base_addr);

    // Small delay between transactions
    usleep(10);
}

/*****************************************************************************
 * Read the ADXL345 device ID
 *****************************************************************************/
u8 ADXL345_ReadDeviceID(u32 base_addr)
{
    return SPI_ReadByte(base_addr, ADXL345_DEVID);
}

/*****************************************************************************
 * Initialize the ADXL345 accelerometer
 *****************************************************************************/
int ADXL345_Init(u32 base_addr)
{
    u8 device_id;

    // Initialize SPI controller
    SPI_Init(base_addr);

    // Wait for device to be ready
    usleep(100000);  // 100ms delay

    // Read and verify device ID
    device_id = ADXL345_ReadDeviceID(base_addr);
    if (device_id != ADXL345_DEVICE_ID_VALUE) {
        // Device ID mismatch - initialization failed
        return -1;
    }

    // Configure DATA_FORMAT register
    // Set to ±4g range with full resolution (11-bit)
    SPI_WriteByte(base_addr, ADXL345_DATA_FORMAT, ADXL345_DATA_FORMAT_4G);
    usleep(1000);

    // Configure POWER_CTL register
    // Enable measurement mode
    SPI_WriteByte(base_addr, ADXL345_POWER_CTL, ADXL345_POWER_CTL_MEASURE);
    usleep(1000);

    // Initialization successful
    return 0;
}

/*****************************************************************************
 * Read acceleration data from all three axes
 *****************************************************************************/
void ADXL345_ReadAccel(u32 base_addr, AccelData *accel_data)
{
    u8 data[6];

    // Read 6 bytes starting from DATAX0 (X, Y, Z data)
    SPI_ReadMultiBytes(base_addr, ADXL345_DATAX0, data, 6);

    // Combine LSB and MSB for each axis
    // ADXL345 returns data in little-endian format (LSB first)
    accel_data->x = (s16)((data[1] << 8) | data[0]);
    accel_data->y = (s16)((data[3] << 8) | data[2]);
    accel_data->z = (s16)((data[5] << 8) | data[4]);
}

/*****************************************************************************
 * Convert raw acceleration data to g-force (±4g range)
 * ADXL345 scale factor for ±4g range: 8 mg/LSB (11-bit resolution)
 * 1 LSB = 0.008 g
 *****************************************************************************/
float ADXL345_ConvertToG(s16 raw_value)
{
    // Scale factor: 8 mg/LSB = 0.008 g/LSB
    return (float)raw_value * 0.008f;
}
