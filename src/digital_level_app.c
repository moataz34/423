/******************************************************************************
 * @file digital_level_app.c
 * @brief Digital Level Application using ADXL345 Accelerometer
 *
 * This application implements a digital level that displays the inclination
 * angle in the Y-Z plane. The accelerometer is read every 500ms via a timer
 * interrupt, and the angle is displayed on the UART terminal.
 *
 * @author Your Name
 * @date November 2025
 *****************************************************************************/

#include "xparameters.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "xtmrctr.h"
#include "xil_exception.h"
#include "spi_driver.h"
#include <math.h>

/*****************************************************************************
 * Hardware Parameters - UPDATE THESE TO MATCH YOUR DESIGN
 *****************************************************************************/
#define SPI_MASTER_BASEADDR     XPAR_SPI_MASTER_AXI_0_S00_AXI_BASEADDR
#define TIMER_DEVICE_ID         XPAR_TMRCTR_0_DEVICE_ID
#define INTC_DEVICE_ID          XPAR_SCUGIC_0_DEVICE_ID
#define TIMER_INTERRUPT_ID      XPAR_FABRIC_TMRCTR_0_VEC_ID

// Timer configuration
#define TIMER_COUNTER_0         0
#define TIMER_LOAD_VALUE        0  // Will be calculated

// SPI Configuration for ADXL345
#define SPI_MODE                SPI_MODE_3
#define SPI_CLK_SCALE           25    // 100MHz / 25 = 4MHz

/*****************************************************************************
 * Global Variables
 *****************************************************************************/
XScuGic InterruptController;    // Interrupt controller instance
XTmrCtr TimerInstance;          // Timer instance

// Accelerometer data (updated in interrupt handler)
volatile s16 g_accel_x = 0;
volatile s16 g_accel_y = 0;
volatile s16 g_accel_z = 0;
volatile float g_angle = 0.0f;
volatile u8 g_new_data = 0;

/*****************************************************************************
 * Function Prototypes
 *****************************************************************************/
int SetupInterruptSystem();
void TimerInterruptHandler(void *CallBackRef, u8 TmrCtrNumber);
void DisplayWelcomeMessage();

/*****************************************************************************
 * Main Function
 *****************************************************************************/
int main()
{
    int status;
    u8 devid;

    xil_printf("\r\n");
    xil_printf("****************************************************\r\n");
    xil_printf("* EECE 423 Project 1: Digital Level Application   *\r\n");
    xil_printf("****************************************************\r\n\r\n");

    // Initialize SPI Master
    xil_printf("Initializing SPI Master...\r\n");
    SPI_Init(SPI_MASTER_BASEADDR, SPI_MODE, SPI_CLK_SCALE);
    xil_printf("  SPI Mode: %d (CPOL=1, CPHA=1)\r\n", SPI_MODE);
    xil_printf("  SPI Clock: 4 MHz\r\n");

    // Small delay to let SPI settle
    for (volatile int i = 0; i < 100000; i++);

    // Initialize ADXL345
    xil_printf("\r\nInitializing ADXL345 Accelerometer...\r\n");

    // Read and verify device ID
    devid = ADXL345_ReadReg(SPI_MASTER_BASEADDR, ADXL345_DEVID);
    xil_printf("  Device ID: 0x%02X ", devid);

    if (devid == ADXL345_EXPECTED_DEVID) {
        xil_printf("(OK)\r\n");
    } else {
        xil_printf("(ERROR - Expected 0x%02X)\r\n", ADXL345_EXPECTED_DEVID);
        xil_printf("\r\nERROR: Failed to communicate with ADXL345!\r\n");
        xil_printf("Check connections:\r\n");
        xil_printf("  - PmodACL should be on JA1 connector\r\n");
        xil_printf("  - IC should be facing UP\r\n");
        xil_printf("  - Verify SPI pin connections\r\n");
        return XST_FAILURE;
    }

    // Initialize ADXL345
    status = ADXL345_Init(SPI_MASTER_BASEADDR);
    if (status != 0) {
        xil_printf("ERROR: ADXL345 initialization failed!\r\n");
        return XST_FAILURE;
    }
    xil_printf("  Range: ±4g\r\n");
    xil_printf("  Resolution: 11-bit\r\n");

    // Setup interrupt system
    xil_printf("\r\nSetting up Timer and Interrupts...\r\n");
    status = SetupInterruptSystem();
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: Failed to setup interrupt system!\r\n");
        return XST_FAILURE;
    }
    xil_printf("  Timer configured for 500ms intervals\r\n");

    xil_printf("\r\n****************************************************\r\n");
    xil_printf("* Digital Level - Y-Z Plane Inclination            *\r\n");
    xil_printf("****************************************************\r\n");
    xil_printf("Tilt the board and observe the angle change...\r\n\r\n");

    // Main loop
    while (1) {
        // Check if new data is available from interrupt handler
        if (g_new_data) {
            g_new_data = 0;

            // Display the angle
            xil_printf("Angle: %6.2f degrees | ", g_angle);
            xil_printf("X: %5d, Y: %5d, Z: %5d\r\n",
                      (int)g_accel_x, (int)g_accel_y, (int)g_accel_z);
        }
    }

    return XST_SUCCESS;
}

/*****************************************************************************
 * Setup Interrupt System
 *****************************************************************************/
int SetupInterruptSystem()
{
    int status;
    XScuGic_Config *IntcConfig;

    // Initialize the interrupt controller
    IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
    if (IntcConfig == NULL) {
        return XST_FAILURE;
    }

    status = XScuGic_CfgInitialize(&InterruptController, IntcConfig,
                                    IntcConfig->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Initialize exception handling
    Xil_ExceptionInit();

    // Register the interrupt controller handler with the exception table
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                  (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                  &InterruptController);

    // Enable exceptions
    Xil_ExceptionEnable();

    // Initialize timer
    status = XTmrCtr_Initialize(&TimerInstance, TIMER_DEVICE_ID);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Set up the timer interrupt handler
    XTmrCtr_SetHandler(&TimerInstance, TimerInterruptHandler, &TimerInstance);

    // Set timer options
    XTmrCtr_SetOptions(&TimerInstance, TIMER_COUNTER_0,
                       XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);

    // Set timer reset value for 500ms
    // Timer clock is typically 100 MHz
    // Reset value = (500ms * 100MHz) = 50,000,000
    // But timer counts down, so we need: 0xFFFFFFFF - 50,000,000 + 1
    u32 reset_value = 0xFFFFFFFF - 50000000 + 1;
    XTmrCtr_SetResetValue(&TimerInstance, TIMER_COUNTER_0, reset_value);

    // Connect timer interrupt to interrupt controller
    status = XScuGic_Connect(&InterruptController, TIMER_INTERRUPT_ID,
                             (Xil_ExceptionHandler)XTmrCtr_InterruptHandler,
                             &TimerInstance);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Enable timer interrupt in the interrupt controller
    XScuGic_Enable(&InterruptController, TIMER_INTERRUPT_ID);

    // Start the timer
    XTmrCtr_Start(&TimerInstance, TIMER_COUNTER_0);

    return XST_SUCCESS;
}

/*****************************************************************************
 * Timer Interrupt Handler
 *
 * This function is called every 500ms. It reads the accelerometer data
 * and calculates the tilt angle in the Y-Z plane.
 *****************************************************************************/
void TimerInterruptHandler(void *CallBackRef, u8 TmrCtrNumber)
{
    s16 x, y, z;

    // Read acceleration data from ADXL345
    ADXL345_ReadAccel(SPI_MASTER_BASEADDR, &x, &y, &z);

    // Update global variables
    g_accel_x = x;
    g_accel_y = y;
    g_accel_z = z;

    // Calculate angle in Y-Z plane
    g_angle = ADXL345_CalculateAngle(y, z);

    // Set flag to indicate new data is available
    g_new_data = 1;
}
