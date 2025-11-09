/******************************************************************************
 * @file spi_driver.h
 * @brief Driver header for AXI-Lite SPI Master
 *
 * This file contains function prototypes and definitions for interfacing
 * with the AXI-Lite SPI Master IP block and the ADXL345 accelerometer.
 *
 * @author Your Name
 * @date November 2025
 *****************************************************************************/

#ifndef SPI_DRIVER_H
#define SPI_DRIVER_H

#include "xil_types.h"
#include "xil_io.h"

/*****************************************************************************
 * Register Offsets
 *****************************************************************************/
#define SPI_CONTROL_REG_OFFSET      0x00
#define SPI_CONFIG_REG_OFFSET       0x04
#define SPI_TX_DATA_REG_OFFSET      0x08
#define SPI_RX_DATA_REG_OFFSET      0x0C
#define SPI_STATUS_REG_OFFSET       0x10

/*****************************************************************************
 * Status Register Bit Masks
 *****************************************************************************/
#define SPI_STATUS_TX_READY         0x00000001
#define SPI_STATUS_RX_VALID         0x00000002
#define SPI_STATUS_RX_COUNT_MASK    0x00000F00

/*****************************************************************************
 * SPI Mode Definitions
 *****************************************************************************/
#define SPI_MODE_0                  0x00  // CPOL=0, CPHA=0
#define SPI_MODE_1                  0x01  // CPOL=0, CPHA=1
#define SPI_MODE_2                  0x02  // CPOL=1, CPHA=0
#define SPI_MODE_3                  0x03  // CPOL=1, CPHA=1

/*****************************************************************************
 * ADXL345 Register Addresses
 *****************************************************************************/
#define ADXL345_DEVID               0x00  // Device ID (should be 0xE5)
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
#define ADXL345_DATAX0              0x32
#define ADXL345_DATAX1              0x33
#define ADXL345_DATAY0              0x34
#define ADXL345_DATAY1              0x35
#define ADXL345_DATAZ0              0x36
#define ADXL345_DATAZ1              0x37
#define ADXL345_FIFO_CTL            0x38
#define ADXL345_FIFO_STATUS         0x39

/*****************************************************************************
 * ADXL345 Register Values
 *****************************************************************************/
#define ADXL345_EXPECTED_DEVID      0xE5

// DATA_FORMAT register bits
#define ADXL345_DATA_FORMAT_RANGE_2G    0x00
#define ADXL345_DATA_FORMAT_RANGE_4G    0x01
#define ADXL345_DATA_FORMAT_RANGE_8G    0x02
#define ADXL345_DATA_FORMAT_RANGE_16G   0x03
#define ADXL345_DATA_FORMAT_JUSTIFY     0x04
#define ADXL345_DATA_FORMAT_FULL_RES    0x08

// POWER_CTL register bits
#define ADXL345_POWER_CTL_MEASURE       0x08
#define ADXL345_POWER_CTL_SLEEP         0x04

/*****************************************************************************
 * Function Prototypes - SPI Master Control
 *****************************************************************************/

/**
 * @brief Initialize the SPI Master
 * @param BaseAddress - Base address of the SPI Master IP
 * @param spi_mode - SPI mode (0-3)
 * @param clk_scale - Clock divider (e.g., 25 for 4MHz from 100MHz)
 */
void SPI_Init(u32 BaseAddress, u8 spi_mode, u16 clk_scale);

/**
 * @brief Configure TX count
 * @param BaseAddress - Base address of the SPI Master IP
 * @param tx_count - Number of bytes to transfer (1-16)
 */
void SPI_SetTxCount(u32 BaseAddress, u8 tx_count);

/**
 * @brief Write a single byte to SPI
 * @param BaseAddress - Base address of the SPI Master IP
 * @param data - Byte to write
 */
void SPI_WriteByte(u32 BaseAddress, u8 data);

/**
 * @brief Read a single byte from SPI
 * @param BaseAddress - Base address of the SPI Master IP
 * @return Received byte
 */
u8 SPI_ReadByte(u32 BaseAddress);

/**
 * @brief Check if SPI master is ready for new transmission
 * @param BaseAddress - Base address of the SPI Master IP
 * @return 1 if ready, 0 if busy
 */
u8 SPI_IsReady(u32 BaseAddress);

/**
 * @brief Wait until SPI master is ready
 * @param BaseAddress - Base address of the SPI Master IP
 */
void SPI_WaitReady(u32 BaseAddress);

/**
 * @brief Check if new RX data is available
 * @param BaseAddress - Base address of the SPI Master IP
 * @return 1 if data available, 0 otherwise
 */
u8 SPI_IsRxValid(u32 BaseAddress);

/**
 * @brief Wait until RX data is valid
 * @param BaseAddress - Base address of the SPI Master IP
 */
void SPI_WaitRxValid(u32 BaseAddress);

/*****************************************************************************
 * Function Prototypes - ADXL345 Control
 *****************************************************************************/

/**
 * @brief Initialize ADXL345 accelerometer
 * @param BaseAddress - Base address of the SPI Master IP
 * @return 0 on success, -1 on failure
 */
int ADXL345_Init(u32 BaseAddress);

/**
 * @brief Write to an ADXL345 register
 * @param BaseAddress - Base address of the SPI Master IP
 * @param reg_addr - Register address (6 bits)
 * @param data - Data to write
 */
void ADXL345_WriteReg(u32 BaseAddress, u8 reg_addr, u8 data);

/**
 * @brief Read from an ADXL345 register
 * @param BaseAddress - Base address of the SPI Master IP
 * @param reg_addr - Register address (6 bits)
 * @return Data read from register
 */
u8 ADXL345_ReadReg(u32 BaseAddress, u8 reg_addr);

/**
 * @brief Read multiple bytes from ADXL345
 * @param BaseAddress - Base address of the SPI Master IP
 * @param reg_addr - Starting register address
 * @param buffer - Buffer to store read data
 * @param count - Number of bytes to read (max 16)
 */
void ADXL345_ReadMultiple(u32 BaseAddress, u8 reg_addr, u8* buffer, u8 count);

/**
 * @brief Read X, Y, Z acceleration data
 * @param BaseAddress - Base address of the SPI Master IP
 * @param x - Pointer to store X acceleration
 * @param y - Pointer to store Y acceleration
 * @param z - Pointer to store Z acceleration
 */
void ADXL345_ReadAccel(u32 BaseAddress, s16* x, s16* y, s16* z);

/**
 * @brief Calculate tilt angle in Y-Z plane
 * @param y - Y acceleration value
 * @param z - Z acceleration value
 * @return Angle in degrees
 */
float ADXL345_CalculateAngle(s16 y, s16 z);

#endif // SPI_DRIVER_H
