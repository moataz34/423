`timescale 1 ns / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company: American University of Beirut
// Engineer:
//
// Module Name: spi_accelerometer_v1_0
// Description: Top-level wrapper for AXI-Lite SPI Master IP
//              Connects to ADXL345 accelerometer via SPI
//////////////////////////////////////////////////////////////////////////////////

module spi_accelerometer_v1_0 #
(
    // Parameters of Axi Slave Bus Interface S00_AXI
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 6
)
(
    // SPI Interface (connect to external pins)
    output wire o_SPI_Clk,
    input wire i_SPI_MISO,
    output wire o_SPI_MOSI,
    output wire o_SPI_CS_n,

    // Ports of Axi Slave Bus Interface S00_AXI
    input wire s00_axi_aclk,
    input wire s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr,
    input wire [2:0] s00_axi_awprot,
    input wire s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
    input wire s00_axi_wvalid,
    output wire s00_axi_wready,
    output wire [1:0] s00_axi_bresp,
    output wire s00_axi_bvalid,
    input wire s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr,
    input wire [2:0] s00_axi_arprot,
    input wire s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata,
    output wire [1:0] s00_axi_rresp,
    output wire s00_axi_rvalid,
    input wire s00_axi_rready
);

    // Internal signals connecting AXI interface to SPI master
    wire [1:0] spi_mode;
    wire [15:0] clk_scale;
    wire [2:0] cs_inactive_clks;
    wire [4:0] tx_count;
    wire [7:0] tx_byte;
    wire tx_dv;
    wire tx_ready;
    wire [3:0] rx_count;
    wire rx_dv;
    wire [7:0] rx_byte;

    // Instantiation of Axi Bus Interface S00_AXI
    spi_accelerometer_v1_0_S00_AXI # (
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) spi_accelerometer_v1_0_S00_AXI_inst (
        // SPI Master interface
        .spi_mode(spi_mode),
        .clk_scale(clk_scale),
        .cs_inactive_clks(cs_inactive_clks),
        .tx_count(tx_count),
        .tx_byte(tx_byte),
        .tx_dv(tx_dv),
        .tx_ready(tx_ready),
        .rx_count(rx_count),
        .rx_dv(rx_dv),
        .rx_byte(rx_byte),

        // AXI interface
        .S_AXI_ACLK(s00_axi_aclk),
        .S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR(s00_axi_awaddr),
        .S_AXI_AWPROT(s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),
        .S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA(s00_axi_wdata),
        .S_AXI_WSTRB(s00_axi_wstrb),
        .S_AXI_WVALID(s00_axi_wvalid),
        .S_AXI_WREADY(s00_axi_wready),
        .S_AXI_BRESP(s00_axi_bresp),
        .S_AXI_BVALID(s00_axi_bvalid),
        .S_AXI_BREADY(s00_axi_bready),
        .S_AXI_ARADDR(s00_axi_araddr),
        .S_AXI_ARPROT(s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),
        .S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA(s00_axi_rdata),
        .S_AXI_RRESP(s00_axi_rresp),
        .S_AXI_RVALID(s00_axi_rvalid),
        .S_AXI_RREADY(s00_axi_rready)
    );

    // Instantiation of SPI Internal
    spi_internal spi_internal_inst (
        .i_Rst_L(s00_axi_aresetn),
        .i_Clk(s00_axi_aclk),
        .i_spi_mode(spi_mode),
        .i_clk_scale(clk_scale),
        .i_cs_inactive_clks(cs_inactive_clks),
        .i_TX_Count(tx_count),
        .i_TX_Byte(tx_byte),
        .i_TX_DV(tx_dv),
        .o_TX_Ready(tx_ready),
        .o_RX_Count(rx_count),
        .o_RX_DV(rx_dv),
        .o_RX_Byte(rx_byte),
        .o_SPI_Clk(o_SPI_Clk),
        .i_SPI_MISO(i_SPI_MISO),
        .o_SPI_MOSI(o_SPI_MOSI),
        .o_SPI_CS_n(o_SPI_CS_n)
    );

endmodule
