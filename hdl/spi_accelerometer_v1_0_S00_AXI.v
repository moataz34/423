`timescale 1 ns / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company: American University of Beirut
// Engineer:
//
// Module Name: spi_accelerometer_v1_0_S00_AXI
// Description: AXI-Lite slave interface for SPI Master
//
// Register Map:
// 0x00: CONTROL_REG
//       [1:0]   - SPI Mode (CPOL, CPHA)
//       [17:2]  - Clock Scale (16 bits)
//       [20:18] - CS Inactive Clocks (3 bits)
// 0x04: TX_COUNT_REG
//       [4:0]   - Number of bytes to transfer (1-16)
// 0x08: TX_DATA_REG
//       [7:0]   - TX Data Byte (write triggers transfer if TX_Ready)
// 0x0C: STATUS_REG (Read Only)
//       [0]     - TX Ready
//       [1]     - RX Data Valid
// 0x10: RX_COUNT_REG (Read Only)
//       [3:0]   - RX Byte Count (0-15)
// 0x14: RX_DATA_REG (Read Only)
//       [7:0]   - RX Data Byte
//////////////////////////////////////////////////////////////////////////////////

module spi_accelerometer_v1_0_S00_AXI #
(
    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
    // SPI Master interface signals
    output wire [1:0] spi_mode,
    output wire [15:0] clk_scale,
    output wire [2:0] cs_inactive_clks,
    output wire [4:0] tx_count,
    output wire [7:0] tx_byte,
    output wire tx_dv,
    input wire tx_ready,
    input wire [3:0] rx_count,
    input wire rx_dv,
    input wire [7:0] rx_byte,

    // AXI4-Lite signals
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire [2:0] S_AXI_AWPROT,
    input wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire S_AXI_WVALID,
    output wire S_AXI_WREADY,
    output wire [1:0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire [2:0] S_AXI_ARPROT,
    input wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0] S_AXI_RRESP,
    output wire S_AXI_RVALID,
    input wire S_AXI_RREADY
);

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // Register addresses
    localparam CONTROL_REG_ADDR   = 3'h0;
    localparam TX_COUNT_REG_ADDR  = 3'h1;
    localparam TX_DATA_REG_ADDR   = 3'h2;
    localparam STATUS_REG_ADDR    = 3'h3;
    localparam RX_COUNT_REG_ADDR  = 3'h4;
    localparam RX_DATA_REG_ADDR   = 3'h5;

    // Internal registers
    reg [20:0] control_reg;     // SPI mode, clock scale, cs_inactive
    reg [4:0] tx_count_reg;
    reg [7:0] tx_data_reg;
    reg tx_data_write;

    // Capture RX data when valid
    reg [7:0] rx_data_reg;
    reg [3:0] rx_count_reg;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rx_data_reg <= 8'd0;
            rx_count_reg <= 4'd0;
        end else begin
            if (rx_dv) begin
                rx_data_reg <= rx_byte;
                rx_count_reg <= rx_count;
            end
        end
    end

    // Output assignments from registers
    assign spi_mode = control_reg[1:0];
    assign clk_scale = control_reg[17:2];
    assign cs_inactive_clks = control_reg[20:18];
    assign tx_count = tx_count_reg;
    assign tx_byte = tx_data_reg;
    assign tx_dv = tx_data_write;

    // I/O Connections assignments
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY = axi_wready;
    assign S_AXI_BRESP = axi_bresp;
    assign S_AXI_BVALID = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA = axi_rdata;
    assign S_AXI_RRESP = axi_rresp;
    assign S_AXI_RVALID = axi_rvalid;

    // Implement axi_awready generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
        end else begin
            if (!axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
                axi_awready <= 1'b1;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // Implement axi_awaddr latching
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awaddr <= 0;
        end else begin
            if (!axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
                axi_awaddr <= S_AXI_AWADDR;
            end
        end
    end

    // Implement axi_wready generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (!axi_wready && S_AXI_WVALID && S_AXI_AWVALID) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // Implement memory mapped register write logic
    wire slv_reg_wren;
    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            control_reg <= 21'h000019;  // Default: mode 3 (CPOL=1, CPHA=1), scale=25, cs_inactive=1
            tx_count_reg <= 5'd1;
            tx_data_reg <= 8'd0;
            tx_data_write <= 1'b0;
        end else begin
            tx_data_write <= 1'b0;  // Pulse signal

            if (slv_reg_wren) begin
                case (axi_awaddr[4:2])
                    CONTROL_REG_ADDR: begin
                        if (S_AXI_WSTRB[0]) control_reg[7:0] <= S_AXI_WDATA[7:0];
                        if (S_AXI_WSTRB[1]) control_reg[15:8] <= S_AXI_WDATA[15:8];
                        if (S_AXI_WSTRB[2]) control_reg[20:16] <= S_AXI_WDATA[20:16];
                    end
                    TX_COUNT_REG_ADDR: begin
                        if (S_AXI_WSTRB[0]) tx_count_reg <= S_AXI_WDATA[4:0];
                    end
                    TX_DATA_REG_ADDR: begin
                        if (S_AXI_WSTRB[0]) begin
                            tx_data_reg <= S_AXI_WDATA[7:0];
                            tx_data_write <= 1'b1;
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    // Implement write response logic generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 0;
            axi_bresp <= 2'b0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && !axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b0;
            end else begin
                if (S_AXI_BREADY && axi_bvalid) begin
                    axi_bvalid <= 1'b0;
                end
            end
        end
    end

    // Implement axi_arready generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr <= 32'b0;
        end else begin
            if (!axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // Implement axi_rvalid generation
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 0;
            axi_rresp <= 0;
        end else begin
            if (axi_arready && S_AXI_ARVALID && !axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b0;
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // Implement memory mapped register read logic
    reg [31:0] reg_data_out;

    always @(*) begin
        case (axi_araddr[4:2])
            CONTROL_REG_ADDR:
                reg_data_out = {11'h000, control_reg};
            TX_COUNT_REG_ADDR:
                reg_data_out = {27'h0, tx_count_reg};
            TX_DATA_REG_ADDR:
                reg_data_out = {24'h0, tx_data_reg};
            STATUS_REG_ADDR:
                reg_data_out = {30'h0, rx_dv, tx_ready};
            RX_COUNT_REG_ADDR:
                reg_data_out = {28'h0, rx_count_reg};
            RX_DATA_REG_ADDR:
                reg_data_out = {24'h0, rx_data_reg};
            default:
                reg_data_out = 32'h00000000;
        endcase
    end

    // Output register or memory read data
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rdata <= 0;
        end else begin
            if (slv_reg_rden) begin
                axi_rdata <= reg_data_out;
            end
        end
    end

    wire slv_reg_rden;
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

endmodule
