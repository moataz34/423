`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: American University of Beirut
// Engineer:
//
// Module Name: spi_internal
// Description: SPI Master module supporting configurable CPOL/CPHA modes
//              and multi-byte transfers
//////////////////////////////////////////////////////////////////////////////////

module spi_internal(
    // Control signals
    input wire i_Rst_L,
    input wire i_Clk,
    input wire [1:0] i_spi_mode,       // {CPOL, CPHA}
    input wire [15:0] i_clk_scale,     // Clock divider (e.g., 25 for 4 MHz from 100 MHz)
    input wire [2:0] i_cs_inactive_clks, // Minimum cycles between transfers

    // TX interface
    input wire [4:0] i_TX_Count,       // Number of bytes to transfer (1-16)
    input wire [7:0] i_TX_Byte,        // Data byte to transmit
    input wire i_TX_DV,                // Data valid signal
    output wire o_TX_Ready,            // Ready to accept new data

    // RX interface
    output reg [3:0] o_RX_Count,       // Index of received byte (0-15)
    output reg o_RX_DV,                // Received data valid
    output reg [7:0] o_RX_Byte,        // Received data byte

    // SPI interface
    output reg o_SPI_Clk,
    input wire i_SPI_MISO,
    output reg o_SPI_MOSI,
    output reg o_SPI_CS_n
);

    // State machine states
    localparam IDLE = 3'b000;
    localparam LOAD_BYTE = 3'b001;
    localparam TRANSFER = 3'b010;
    localparam WAIT_CS = 3'b011;

    reg [2:0] state;
    reg [2:0] next_state;

    // Clock generation
    reg [15:0] clk_counter;
    reg spi_clk_en;
    reg spi_clk_toggle;

    // Data shift registers
    reg [7:0] tx_shift_reg;
    reg [7:0] rx_shift_reg;

    // Bit counter
    reg [3:0] bit_counter;

    // Byte counter
    reg [4:0] byte_counter;
    reg [4:0] total_bytes;

    // CS inactive counter
    reg [2:0] cs_inactive_counter;

    // Edge detection
    reg spi_clk_prev;
    wire spi_clk_rising;
    wire spi_clk_falling;

    // CPOL and CPHA
    wire cpol = i_spi_mode[1];
    wire cpha = i_spi_mode[0];

    // Ready signal - high when idle
    assign o_TX_Ready = (state == IDLE);

    // Clock edge detection
    assign spi_clk_rising = (o_SPI_Clk && !spi_clk_prev);
    assign spi_clk_falling = (!o_SPI_Clk && spi_clk_prev);

    // Determine sampling and output edges based on CPHA
    wire sample_edge = cpha ? spi_clk_rising : spi_clk_falling;
    wire output_edge = cpha ? spi_clk_falling : spi_clk_rising;

    // Clock generation logic
    always @(posedge i_Clk or negedge i_Rst_L) begin
        if (!i_Rst_L) begin
            clk_counter <= 16'd0;
            spi_clk_toggle <= 1'b0;
        end else begin
            if (state == TRANSFER || (state == LOAD_BYTE && cpha == 1'b0)) begin
                if (clk_counter >= i_clk_scale - 1) begin
                    clk_counter <= 16'd0;
                    spi_clk_toggle <= 1'b1;
                end else begin
                    clk_counter <= clk_counter + 1;
                    spi_clk_toggle <= 1'b0;
                end
            end else begin
                clk_counter <= 16'd0;
                spi_clk_toggle <= 1'b0;
            end
        end
    end

    // SPI clock generation
    always @(posedge i_Clk or negedge i_Rst_L) begin
        if (!i_Rst_L) begin
            o_SPI_Clk <= 1'b0;
            spi_clk_prev <= 1'b0;
        end else begin
            spi_clk_prev <= o_SPI_Clk;

            if (state == IDLE || state == WAIT_CS) begin
                o_SPI_Clk <= cpol;  // Clock idle state based on CPOL
            end else if (spi_clk_toggle) begin
                o_SPI_Clk <= ~o_SPI_Clk;
            end
        end
    end

    // State machine - combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (i_TX_DV) begin
                    next_state = LOAD_BYTE;
                end
            end

            LOAD_BYTE: begin
                next_state = TRANSFER;
            end

            TRANSFER: begin
                if (bit_counter == 4'd8 && spi_clk_toggle) begin
                    if (byte_counter >= total_bytes) begin
                        next_state = WAIT_CS;
                    end else begin
                        next_state = LOAD_BYTE;
                    end
                end
            end

            WAIT_CS: begin
                if (cs_inactive_counter == 3'd0) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // State machine - sequential state transition
    always @(posedge i_Clk or negedge i_Rst_L) begin
        if (!i_Rst_L) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main control logic
    always @(posedge i_Clk or negedge i_Rst_L) begin
        if (!i_Rst_L) begin
            o_SPI_CS_n <= 1'b1;
            o_SPI_MOSI <= 1'b0;
            tx_shift_reg <= 8'd0;
            rx_shift_reg <= 8'd0;
            bit_counter <= 4'd0;
            byte_counter <= 5'd0;
            total_bytes <= 5'd0;
            o_RX_Count <= 4'd0;
            o_RX_DV <= 1'b0;
            o_RX_Byte <= 8'd0;
            cs_inactive_counter <= 3'd0;
        end else begin
            // Default assignments
            o_RX_DV <= 1'b0;

            case (state)
                IDLE: begin
                    o_SPI_CS_n <= 1'b1;
                    bit_counter <= 4'd0;
                    byte_counter <= 5'd0;
                    o_RX_Count <= 4'd0;

                    if (i_TX_DV) begin
                        total_bytes <= i_TX_Count;
                        tx_shift_reg <= i_TX_Byte;
                        byte_counter <= 5'd1;
                    end
                end

                LOAD_BYTE: begin
                    o_SPI_CS_n <= 1'b0;
                    bit_counter <= 4'd0;

                    if (state != TRANSFER) begin  // Just entered LOAD_BYTE
                        if (byte_counter == 5'd1) begin
                            // First byte already loaded in IDLE
                        end else begin
                            // Load next byte
                            if (i_TX_DV) begin
                                tx_shift_reg <= i_TX_Byte;
                            end
                        end

                        // For CPHA=0, output first bit immediately
                        if (cpha == 1'b0) begin
                            o_SPI_MOSI <= tx_shift_reg[7];
                        end
                    end
                end

                TRANSFER: begin
                    o_SPI_CS_n <= 1'b0;

                    // Sample on appropriate edge
                    if (sample_edge && bit_counter < 4'd8) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], i_SPI_MISO};
                    end

                    // Output on appropriate edge
                    if (output_edge && bit_counter < 4'd8) begin
                        if (cpha == 1'b1 && bit_counter == 4'd0) begin
                            // CPHA=1: output first bit on first falling edge
                            o_SPI_MOSI <= tx_shift_reg[7];
                        end else begin
                            o_SPI_MOSI <= tx_shift_reg[6];
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end

                    // Increment bit counter
                    if (spi_clk_toggle) begin
                        if ((cpha == 1'b0 && spi_clk_falling) ||
                            (cpha == 1'b1 && spi_clk_rising)) begin
                            bit_counter <= bit_counter + 1;

                            // Check if byte transfer complete
                            if (bit_counter == 4'd7) begin
                                o_RX_Byte <= {rx_shift_reg[6:0], i_SPI_MISO};
                                o_RX_DV <= 1'b1;
                                o_RX_Count <= byte_counter - 1;

                                if (byte_counter < total_bytes) begin
                                    byte_counter <= byte_counter + 1;
                                end
                            end
                        end
                    end
                end

                WAIT_CS: begin
                    o_SPI_CS_n <= 1'b1;
                    if (cs_inactive_counter == 3'd0) begin
                        cs_inactive_counter <= i_cs_inactive_clks;
                    end else begin
                        cs_inactive_counter <= cs_inactive_counter - 1;
                    end
                end

                default: begin
                    o_SPI_CS_n <= 1'b1;
                end
            endcase
        end
    end

endmodule
