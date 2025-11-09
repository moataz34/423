/******************************************************************************
 * File: main.c
 * Description: Digital Level Application using ADXL345 Accelerometer
 *              Calculates inclination angle in Y-Z plane
 * Author: EECE 423 Project
 * Institution: American University of Beirut
 ******************************************************************************/

#include "spi_accelerometer.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "xtmrctr.h"
#include "xil_exception.h"
#include <math.h>

/*****************************************************************************
 * Device Parameters - Update these with your actual base addresses
 *****************************************************************************/
#define SPI_ACCELEROMETER_BASEADDR      XPAR_SPI_ACCELEROMETER_0_S00_AXI_BASEADDR
#define TIMER_DEVICE_ID         XPAR_TMRCTR_0_DEVICE_ID
#define INTC_DEVICE_ID          XPAR_SCUGIC_SINGLE_DEVICE_ID
#define TIMER_INTERRUPT_ID      XPAR_FABRIC_TMRCTR_0_VEC_ID

// Timer configuration for 500ms interrupts
// Assuming 100 MHz clock
#define TIMER_FREQ_HZ           100000000
#define TIMER_INTERVAL_MS       500
#define TIMER_LOAD_VALUE        (TIMER_FREQ_HZ / 1000 * TIMER_INTERVAL_MS)

/*****************************************************************************
 * Global Variables
 *****************************************************************************/
XScuGic InterruptController;    // GIC instance
XTmrCtr TimerInstance;          // Timer instance

// Global acceleration data (updated by interrupt handler)
volatile AccelData g_accel_data;
volatile int g_new_data = 0;

/*****************************************************************************
 * Function Prototypes
 *****************************************************************************/
int SetupInterruptSystem(XScuGic *IntcInstancePtr, XTmrCtr *TmrInstancePtr, u16 TimerId);
void TimerInterruptHandler(void *CallBackRef, u8 TmrNumber);
float CalculateInclination(float ay, float az);
void DisplayInclination(float angle);

/*****************************************************************************
 * Main Function
 *****************************************************************************/
int main(void)
{
    int status;
    float ay, az, angle;

    xil_printf("\r\n");
    xil_printf("====================================\r\n");
    xil_printf(" EECE 423 - Digital Level\r\n");
    xil_printf(" ADXL345 Accelerometer\r\n");
    xil_printf("====================================\r\n");
    xil_printf("\r\n");

    // Initialize SPI and ADXL345
    xil_printf("Initializing ADXL345...\r\n");
    status = ADXL345_Init(SPI_ACCELEROMETER_BASEADDR);
    if (status != 0) {
        xil_printf("ERROR: ADXL345 initialization failed!\r\n");
        xil_printf("Device ID mismatch. Check connections.\r\n");
        return -1;
    }
    xil_printf("ADXL345 initialized successfully.\r\n");

    // Verify device ID
    u8 device_id = ADXL345_ReadDeviceID(SPI_ACCELEROMETER_BASEADDR);
    xil_printf("Device ID: 0x%02X (Expected: 0xE5)\r\n", device_id);

    // Initialize Timer
    xil_printf("\r\nInitializing Timer...\r\n");
    status = XTmrCtr_Initialize(&TimerInstance, TIMER_DEVICE_ID);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: Timer initialization failed!\r\n");
        return -1;
    }

    // Set timer options
    XTmrCtr_SetOptions(&TimerInstance, 0,
                       XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION | XTC_DOWN_COUNT_OPTION);

    // Set timer reset value for 500ms interval
    XTmrCtr_SetResetValue(&TimerInstance, 0, TIMER_LOAD_VALUE);

    // Setup interrupt system
    xil_printf("Setting up interrupts...\r\n");
    status = SetupInterruptSystem(&InterruptController, &TimerInstance, TIMER_INTERRUPT_ID);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: Interrupt setup failed!\r\n");
        return -1;
    }

    // Start the timer
    xil_printf("Starting timer (500ms interval)...\r\n");
    XTmrCtr_Start(&TimerInstance, 0);

    xil_printf("\r\n");
    xil_printf("====================================\r\n");
    xil_printf(" Digital Level Active\r\n");
    xil_printf(" Reading Y-Z Plane Inclination\r\n");
    xil_printf("====================================\r\n");
    xil_printf("\r\n");

    // Main loop - process data when available
    while (1) {
        if (g_new_data) {
            // Convert raw values to g-force
            ay = ADXL345_ConvertToG(g_accel_data.y);
            az = ADXL345_ConvertToG(g_accel_data.z);

            // Calculate inclination angle
            angle = CalculateInclination(ay, az);

            // Display results
            DisplayInclination(angle);

            // Clear new data flag
            g_new_data = 0;
        }
    }

    return 0;
}

/*****************************************************************************
 * Timer Interrupt Handler
 * Called every 500ms to read accelerometer data
 *****************************************************************************/
void TimerInterruptHandler(void *CallBackRef, u8 TmrNumber)
{
    AccelData local_data;

    // Read accelerometer data
    ADXL345_ReadAccel(SPI_ACCELEROMETER_BASEADDR, &local_data);

    // Update global data
    g_accel_data.x = local_data.x;
    g_accel_data.y = local_data.y;
    g_accel_data.z = local_data.z;

    // Set new data flag
    g_new_data = 1;
}

/*****************************************************************************
 * Calculate Inclination Angle in Y-Z Plane
 * Returns angle in degrees
 *
 * When the board is flat (horizontal):
 *   - Y acceleration ≈ 0g
 *   - Z acceleration ≈ 1g (gravity pointing down)
 *   - Angle ≈ 0°
 *
 * When tilted in Y-Z plane:
 *   - Angle = atan2(Ay, Az) * 180/π
 *
 * This gives the angle of inclination from horizontal in the Y-Z plane
 *****************************************************************************/
float CalculateInclination(float ay, float az)
{
    float angle_rad;
    float angle_deg;

    // Calculate angle using arctangent
    // atan2 handles all quadrants correctly
    angle_rad = atan2f(ay, az);

    // Convert to degrees
    angle_deg = angle_rad * 180.0f / M_PI;

    return angle_deg;
}

/*****************************************************************************
 * Display Inclination Angle and Acceleration Data
 *****************************************************************************/
void DisplayInclination(float angle)
{
    float ax, ay, az;

    // Convert raw values to g
    ax = ADXL345_ConvertToG(g_accel_data.x);
    ay = ADXL345_ConvertToG(g_accel_data.y);
    az = ADXL345_ConvertToG(g_accel_data.z);

    // Display raw acceleration values
    xil_printf("Accel: X=%d Y=%d Z=%d | ",
               g_accel_data.x, g_accel_data.y, g_accel_data.z);

    // Display g-force values
    xil_printf("G-Force: X=%.3f Y=%.3f Z=%.3f | ", ax, ay, az);

    // Display inclination angle
    xil_printf("Inclination: %.2f°\r\n", angle);
}

/*****************************************************************************
 * Setup Interrupt System
 *****************************************************************************/
int SetupInterruptSystem(XScuGic *IntcInstancePtr, XTmrCtr *TmrInstancePtr, u16 TimerId)
{
    int status;

    // Initialize the interrupt controller
    XScuGic_Config *IntcConfig;
    IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
    if (NULL == IntcConfig) {
        return XST_FAILURE;
    }

    status = XScuGic_CfgInitialize(IntcInstancePtr, IntcConfig, IntcConfig->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Set priority and trigger type
    XScuGic_SetPriorityTriggerType(IntcInstancePtr, TimerId, 0xA0, 0x3);

    // Connect timer interrupt handler
    status = XScuGic_Connect(IntcInstancePtr, TimerId,
                             (Xil_ExceptionHandler)XTmrCtr_InterruptHandler,
                             (void *)TmrInstancePtr);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Enable the interrupt for the timer
    XScuGic_Enable(IntcInstancePtr, TimerId);

    // Set up timer callback
    XTmrCtr_SetHandler(TmrInstancePtr, TimerInterruptHandler, TmrInstancePtr);

    // Initialize the exception table
    Xil_ExceptionInit();

    // Register the interrupt controller handler with the exception table
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                  (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                  IntcInstancePtr);

    // Enable exceptions
    Xil_ExceptionEnable();

    return XST_SUCCESS;
}
