/******************************************************************************
 * @file spi_driver.c
 * @brief Driver implementation for AXI-Lite SPI Master
 *
 * This file contains the implementation of functions for interfacing
 * with the AXI-Lite SPI Master IP block and the ADXL345 accelerometer.
 *
 * @author Your Name
 * @date November 2025
 *****************************************************************************/

#include "spi_driver.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xil_printf.h"
#include <math.h>

/*****************************************************************************
 * SPI Master Control Functions
 *****************************************************************************/

void SPI_Init(u32 BaseAddress, u8 spi_mode, u16 clk_scale)
{
    u32 control_val;
    u32 config_val;
    u32 status_val;

    xil_printf("  [DEBUG] SPI Base Address: 0x%08X\r\n", BaseAddress);

    // Configure CONTROL register: [31:16] = clk_scale, [1:0] = spi_mode
    control_val = ((u32)clk_scale << 16) | (u32)spi_mode;
    Xil_Out32(BaseAddress + SPI_CONTROL_REG_OFFSET, control_val);
    xil_printf("  [DEBUG] CONTROL register written: 0x%08X\r\n", control_val);

    // Configure CONFIG register: [2:0] = cs_inactive_clks (1), [12:8] = tx_count (1)
    config_val = 0x00000101;  // cs_inactive = 1, tx_count = 1
    Xil_Out32(BaseAddress + SPI_CONFIG_REG_OFFSET, config_val);
    xil_printf("  [DEBUG] CONFIG register written: 0x%08X\r\n", config_val);

    // Read and display initial status
    status_val = Xil_In32(BaseAddress + SPI_STATUS_REG_OFFSET);
    xil_printf("  [DEBUG] Initial STATUS register: 0x%08X\r\n", status_val);
}

void SPI_SetTxCount(u32 BaseAddress, u8 tx_count)
{
    u32 config_val;

    // Read current config register
    config_val = Xil_In32(BaseAddress + SPI_CONFIG_REG_OFFSET);

    // Clear TX count bits [12:8] and set new value
    config_val = (config_val & 0xFFFFE0FF) | ((u32)tx_count << 8);

    // Write back
    Xil_Out32(BaseAddress + SPI_CONFIG_REG_OFFSET, config_val);
}

void SPI_WriteByte(u32 BaseAddress, u8 data)
{
    // Wait until SPI is ready
    SPI_WaitReady(BaseAddress);

    // Write data to TX register (this triggers the transfer)
    Xil_Out32(BaseAddress + SPI_TX_DATA_REG_OFFSET, (u32)data);
}

u8 SPI_ReadByte(u32 BaseAddress)
{
    u32 rx_data;

    // Wait for RX data to be valid
    SPI_WaitRxValid(BaseAddress);

    // Read received data
    rx_data = Xil_In32(BaseAddress + SPI_RX_DATA_REG_OFFSET);

    return (u8)(rx_data & 0xFF);
}

u8 SPI_IsReady(u32 BaseAddress)
{
    u32 status;

    status = Xil_In32(BaseAddress + SPI_STATUS_REG_OFFSET);

    return (status & SPI_STATUS_TX_READY) ? 1 : 0;
}

void SPI_WaitReady(u32 BaseAddress)
{
    u32 timeout = 100000;  // Timeout counter

    while (!SPI_IsReady(BaseAddress) && timeout > 0) {
        timeout--;
    }

    if (timeout == 0) {
        // Timeout occurred - print debug info
        u32 status = Xil_In32(BaseAddress + SPI_STATUS_REG_OFFSET);
        xil_printf("WARNING: SPI_WaitReady timeout! Status=0x%08X\r\n", status);
    }
}

u8 SPI_IsRxValid(u32 BaseAddress)
{
    u32 status;

    status = Xil_In32(BaseAddress + SPI_STATUS_REG_OFFSET);

    return (status & SPI_STATUS_RX_VALID) ? 1 : 0;
}

void SPI_WaitRxValid(u32 BaseAddress)
{
    u32 timeout = 100000;  // Timeout counter

    while (!SPI_IsRxValid(BaseAddress) && timeout > 0) {
        timeout--;
    }

    if (timeout == 0) {
        // Timeout occurred - print debug info
        u32 status = Xil_In32(BaseAddress + SPI_STATUS_REG_OFFSET);
        xil_printf("WARNING: SPI_WaitRxValid timeout! Status=0x%08X\r\n", status);
    }
}

/*****************************************************************************
 * ADXL345 Control Functions
 *****************************************************************************/

int ADXL345_Init(u32 BaseAddress)
{
    u8 devid;

    // Read device ID to verify communication
    devid = ADXL345_ReadReg(BaseAddress, ADXL345_DEVID);

    if (devid != ADXL345_EXPECTED_DEVID) {
        // Device ID mismatch - communication error
        return -1;
    }

    // Configure DATA_FORMAT register for ±4g range, 11-bit resolution
    // Bit 0: RANGE = 1 (±4g)
    // Bit 3: FULL_RES = 1 (full resolution mode)
    ADXL345_WriteReg(BaseAddress, ADXL345_DATA_FORMAT, 0x09);

    // Small delay
    for (volatile int i = 0; i < 10000; i++);

    // Configure POWER_CTL register to start measurements
    // Bit 3: Measure = 1 (enable measurement mode)
    ADXL345_WriteReg(BaseAddress, ADXL345_POWER_CTL, ADXL345_POWER_CTL_MEASURE);

    return 0;  // Success
}

void ADXL345_WriteReg(u32 BaseAddress, u8 reg_addr, u8 data)
{
    u8 command;

    // Set TX count to 2 (command byte + data byte)
    SPI_SetTxCount(BaseAddress, 2);

    // Create command byte: [7]=0 (write), [6]=0 (single byte), [5:0]=address
    command = reg_addr & 0x3F;

    // Send command byte
    SPI_WriteByte(BaseAddress, command);

    // Send data byte
    SPI_WriteByte(BaseAddress, data);

    // Wait for transfer to complete
    SPI_WaitReady(BaseAddress);
}

u8 ADXL345_ReadReg(u32 BaseAddress, u8 reg_addr)
{
    u8 command;
    u8 dummy = 0x00;
    u8 received_data;

    xil_printf("  [DEBUG] Reading register 0x%02X...\r\n", reg_addr);

    // Set TX count to 2 (command byte + dummy byte)
    SPI_SetTxCount(BaseAddress, 2);
    xil_printf("  [DEBUG] TX count set to 2\r\n");

    // Create command byte: [7]=1 (read), [6]=0 (single byte), [5:0]=address
    command = 0x80 | (reg_addr & 0x3F);
    xil_printf("  [DEBUG] Command byte: 0x%02X\r\n", command);

    // Send command byte
    xil_printf("  [DEBUG] Sending command byte...\r\n");
    SPI_WriteByte(BaseAddress, command);
    xil_printf("  [DEBUG] Command byte sent\r\n");

    // Read response (ignore it, it's from the command byte transfer)
    xil_printf("  [DEBUG] Reading command response...\r\n");
    SPI_ReadByte(BaseAddress);
    xil_printf("  [DEBUG] Command response read\r\n");

    // Send dummy byte to receive the data
    xil_printf("  [DEBUG] Sending dummy byte...\r\n");
    SPI_WriteByte(BaseAddress, dummy);
    xil_printf("  [DEBUG] Dummy byte sent\r\n");

    // Read the actual data
    xil_printf("  [DEBUG] Reading actual data...\r\n");
    received_data = SPI_ReadByte(BaseAddress);
    xil_printf("  [DEBUG] Data read: 0x%02X\r\n", received_data);

    return received_data;
}

void ADXL345_ReadMultiple(u32 BaseAddress, u8 reg_addr, u8* buffer, u8 count)
{
    u8 command;
    u8 dummy = 0x00;

    if (count > 16) {
        count = 16;  // Limit to maximum supported count
    }

    // Set TX count to count + 1 (command byte + count data bytes)
    SPI_SetTxCount(BaseAddress, count + 1);

    // Create command byte: [7]=1 (read), [6]=1 (multiple bytes), [5:0]=address
    command = 0xC0 | (reg_addr & 0x3F);

    // Send command byte
    SPI_WriteByte(BaseAddress, command);

    // Read response (ignore it)
    SPI_ReadByte(BaseAddress);

    // Read multiple bytes
    for (u8 i = 0; i < count; i++) {
        // Send dummy byte
        SPI_WriteByte(BaseAddress, dummy);

        // Read data byte
        buffer[i] = SPI_ReadByte(BaseAddress);
    }
}

void ADXL345_ReadAccel(u32 BaseAddress, s16* x, s16* y, s16* z)
{
    u8 accel_data[6];

    // Read 6 bytes starting from DATAX0 register (0x32)
    ADXL345_ReadMultiple(BaseAddress, ADXL345_DATAX0, accel_data, 6);

    // Combine bytes into 16-bit signed values
    // Note: ADXL345 stores data as little-endian (LSB first)
    *x = (s16)((accel_data[1] << 8) | accel_data[0]);
    *y = (s16)((accel_data[3] << 8) | accel_data[2]);
    *z = (s16)((accel_data[5] << 8) | accel_data[4]);
}

float ADXL345_CalculateAngle(s16 y, s16 z)
{
    float angle;

    // Calculate angle in radians using atan2
    angle = atan2((float)y, (float)z);

    // Convert to degrees
    angle = angle * 180.0f / M_PI;

    return angle;
}
