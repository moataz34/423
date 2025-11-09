`timescale 1ns / 1ps

/*
 * SPI Master Core Module
 *
 * Implements a configurable SPI master with support for:
 * - All 4 SPI modes (CPOL/CPHA combinations)
 * - Configurable clock scaling
 * - Multi-byte transactions
 * - Full-duplex communication
 */

module spi_master (
    // Control Signals
    input  wire        i_Rst_L,              // Active-low reset
    input  wire        i_Clk,                // System clock (100 MHz)
    input  wire [1:0]  i_spi_mode,           // SPI mode: {CPOL, CPHA}
    input  wire [15:0] i_clk_scale,          // Clock divider for SPI clock
    input  wire [2:0]  i_cs_inactive_clks,   // CS inactive time between transfers

    // TX Interface
    input  wire [4:0]  i_TX_Count,           // Number of bytes to transfer (1-16)
    input  wire [7:0]  i_TX_Byte,            // Byte to transmit
    input  wire        i_TX_DV,              // TX data valid
    output reg         o_TX_Ready,           // TX ready for new data

    // RX Interface
    output reg  [3:0]  o_RX_Count,           // Index of received byte (0-15)
    output reg         o_RX_DV,              // RX data valid
    output reg  [7:0]  o_RX_Byte,            // Received byte

    // SPI Interface
    output reg         o_SPI_Clk,            // SPI clock (SCK)
    input  wire        i_SPI_MISO,           // SPI MISO
    output reg         o_SPI_MOSI,           // SPI MOSI
    output reg         o_SPI_CS_n            // SPI chip select (active low)
);

// SPI Mode parameters
wire CPOL = i_spi_mode[1];
wire CPHA = i_spi_mode[0];

// State machine states
localparam IDLE = 3'd0;
localparam WAIT_HALF = 3'd1;
localparam TRANSFER = 3'd2;
localparam CS_INACTIVE = 3'd3;

reg [2:0] state;
reg [15:0] clk_counter;
reg [2:0] bit_counter;
reg [4:0] byte_counter;
reg [4:0] bytes_to_transfer;
reg [7:0] tx_shift_reg;
reg [7:0] rx_shift_reg;
reg [2:0] cs_inactive_counter;
reg spi_clk_enable;
reg leading_edge;
reg trailing_edge;

// Generate SPI clock based on system clock and scale factor
always @(posedge i_Clk or negedge i_Rst_L)
begin
    if (!i_Rst_L)
    begin
        clk_counter <= 0;
        leading_edge <= 0;
        trailing_edge <= 0;
    end
    else
    begin
        leading_edge <= 0;
        trailing_edge <= 0;

        if (state != IDLE)
        begin
            if (clk_counter >= i_clk_scale - 1)
            begin
                clk_counter <= 0;
                trailing_edge <= 1;
                if (spi_clk_enable)
                    o_SPI_Clk <= ~o_SPI_Clk;
            end
            else
            begin
                clk_counter <= clk_counter + 1;
                if (clk_counter == (i_clk_scale >> 1) - 1)
                begin
                    leading_edge <= 1;
                    if (spi_clk_enable)
                        o_SPI_Clk <= ~o_SPI_Clk;
                end
            end
        end
        else
        begin
            clk_counter <= 0;
            o_SPI_Clk <= CPOL;  // Set clock to idle state
        end
    end
end

// Determine sample and shift edges based on CPHA and CPOL
wire sample_edge = (CPHA == 0) ? leading_edge : trailing_edge;
wire shift_edge = (CPHA == 0) ? trailing_edge : leading_edge;

// Main SPI state machine
always @(posedge i_Clk or negedge i_Rst_L)
begin
    if (!i_Rst_L)
    begin
        state <= IDLE;
        o_TX_Ready <= 1;
        o_RX_DV <= 0;
        o_SPI_CS_n <= 1;
        o_SPI_MOSI <= 0;
        bit_counter <= 0;
        byte_counter <= 0;
        bytes_to_transfer <= 0;
        spi_clk_enable <= 0;
        cs_inactive_counter <= 0;
    end
    else
    begin
        o_RX_DV <= 0;  // Default: no new RX data

        case (state)
            IDLE:
            begin
                o_TX_Ready <= 1;
                o_SPI_CS_n <= 1;
                o_SPI_Clk <= CPOL;
                spi_clk_enable <= 0;
                byte_counter <= 0;

                if (i_TX_DV)
                begin
                    o_TX_Ready <= 0;
                    tx_shift_reg <= i_TX_Byte;
                    bytes_to_transfer <= i_TX_Count;
                    byte_counter <= 0;
                    bit_counter <= 0;
                    o_SPI_CS_n <= 0;  // Assert chip select

                    if (CPHA == 0)
                    begin
                        // Mode 0 or 2: output data immediately
                        o_SPI_MOSI <= i_TX_Byte[7];
                        state <= TRANSFER;
                        spi_clk_enable <= 1;
                    end
                    else
                    begin
                        // Mode 1 or 3: wait for half clock before outputting data
                        state <= WAIT_HALF;
                        spi_clk_enable <= 0;
                    end
                end
            end

            WAIT_HALF:
            begin
                // Wait for half clock period before starting transfer
                if (leading_edge)
                begin
                    o_SPI_MOSI <= tx_shift_reg[7];
                    state <= TRANSFER;
                    spi_clk_enable <= 1;
                end
            end

            TRANSFER:
            begin
                // Sample data on sample_edge
                if (sample_edge)
                begin
                    rx_shift_reg <= {rx_shift_reg[6:0], i_SPI_MISO};
                    bit_counter <= bit_counter + 1;

                    if (bit_counter == 7)
                    begin
                        // Byte transfer complete
                        o_RX_Byte <= {rx_shift_reg[6:0], i_SPI_MISO};
                        o_RX_DV <= 1;
                        o_RX_Count <= byte_counter[3:0];
                        byte_counter <= byte_counter + 1;
                        bit_counter <= 0;

                        if (byte_counter >= bytes_to_transfer - 1)
                        begin
                            // All bytes transferred
                            spi_clk_enable <= 0;
                            cs_inactive_counter <= 0;
                            state <= CS_INACTIVE;
                        end
                        else
                        begin
                            // More bytes to transfer
                            o_TX_Ready <= 1;
                        end
                    end
                end

                // Shift out next bit on shift_edge
                if (shift_edge && bit_counter < 7)
                begin
                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    o_SPI_MOSI <= tx_shift_reg[6];
                end

                // Load new byte if available
                if (i_TX_DV && o_TX_Ready)
                begin
                    tx_shift_reg <= i_TX_Byte;
                    o_TX_Ready <= 0;
                end
            end

            CS_INACTIVE:
            begin
                o_SPI_CS_n <= 1;  // Deassert chip select
                o_SPI_Clk <= CPOL;

                if (clk_counter == 0)
                begin
                    cs_inactive_counter <= cs_inactive_counter + 1;
                    if (cs_inactive_counter >= i_cs_inactive_clks)
                    begin
                        state <= IDLE;
                    end
                end
            end

            default:
                state <= IDLE;
        endcase
    end
end

endmodule
