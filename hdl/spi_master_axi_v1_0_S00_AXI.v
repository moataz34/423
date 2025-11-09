`timescale 1 ns / 1 ps

/*
 * AXI-Lite Slave Interface for SPI Master
 *
 * Register Map:
 * Offset 0x00: CONTROL_REG
 *   [1:0]   - SPI Mode (CPOL, CPHA)
 *   [31:16] - Clock Scale (divide 100MHz to get SPI clock)
 *             For 4MHz SPI clock: clk_scale = 100MHz / 4MHz = 25
 *
 * Offset 0x04: CONFIG_REG
 *   [2:0]   - CS Inactive Clocks (set to 1)
 *   [12:8]  - TX Count (number of bytes to transfer, 1-16)
 *
 * Offset 0x08: TX_DATA_REG
 *   [7:0]   - TX Byte (data to send)
 *   Write to this register triggers TX_DV pulse
 *
 * Offset 0x0C: RX_DATA_REG (Read Only)
 *   [7:0]   - RX Byte (received data)
 *
 * Offset 0x10: STATUS_REG (Read Only)
 *   [0]     - TX Ready (1=ready for new data, 0=busy)
 *   [1]     - RX Data Valid (1=new data received)
 *   [11:8]  - RX Count (index of received byte, 0-15)
 */

module spi_master_axi_v1_0_S00_AXI #
(
    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
    // Users to add ports here
    // SPI Master Control Signals
    output wire [1:0]  o_spi_mode,
    output wire [15:0] o_clk_scale,
    output wire [2:0]  o_cs_inactive_clks,
    output wire [4:0]  o_tx_count,
    output wire [7:0]  o_tx_byte,
    output reg         o_tx_dv,
    input  wire        i_tx_ready,
    input  wire [3:0]  i_rx_count,
    input  wire        i_rx_dv,
    input  wire [7:0]  i_rx_byte,
    // User ports ends

    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, accepted by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
    // privilege and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
    // valid write address and control information.
    input wire  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
    // to accept an address and associated control signals.
    output wire  S_AXI_AWREADY,
    // Write data (issued by master, accepted by Slave)
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input wire  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output wire  S_AXI_WREADY,
    // Write response. This signal indicates the status
    // of the write transaction.
    output wire [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
    // is signaling a valid write response.
    output wire  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input wire  S_AXI_BREADY,
    // Read address (issued by master, accepted by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether the
    // transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
    // is signaling valid read address and control information.
    input wire  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
    // ready to accept an address and associated control signals.
    output wire  S_AXI_ARREADY,
    // Read data (issued by slave)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
    // read transfer.
    output wire [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
    // signaling the required read data.
    output wire  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input wire  S_AXI_RREADY
);

// AXI4LITE signals
reg [C_S_AXI_ADDR_WIDTH-1 : 0]     axi_awaddr;
reg      axi_awready;
reg      axi_wready;
reg [1 : 0]     axi_bresp;
reg      axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH-1 : 0]     axi_araddr;
reg      axi_arready;
reg [C_S_AXI_DATA_WIDTH-1 : 0]     axi_rdata;
reg [1 : 0]     axi_rresp;
reg      axi_rvalid;

// Example-specific design signals
// local parameter for addressing 32 bit / 4 byte aligned
localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 3;

// SPI Control Registers
reg [31:0] control_reg;   // 0x00
reg [31:0] config_reg;    // 0x04
reg [31:0] tx_data_reg;   // 0x08
reg [31:0] rx_data_reg;   // 0x0C
reg [31:0] status_reg;    // 0x10

// Register write pulse
wire     slv_reg_wren;
wire     slv_reg_rden;
reg [31:0]     reg_data_out;
integer     byte_index;
reg     aw_en;

// I/O Connections assignments
assign S_AXI_AWREADY    = axi_awready;
assign S_AXI_WREADY    = axi_wready;
assign S_AXI_BRESP    = axi_bresp;
assign S_AXI_BVALID    = axi_bvalid;
assign S_AXI_ARREADY    = axi_arready;
assign S_AXI_RDATA    = axi_rdata;
assign S_AXI_RRESP    = axi_rresp;
assign S_AXI_RVALID    = axi_rvalid;

// Implement axi_awready generation
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end
  else
    begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
        begin
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
        end
        else if (S_AXI_BREADY && axi_bvalid)
            begin
              aw_en <= 1'b1;
              axi_awready <= 1'b0;
            end
      else
        begin
          axi_awready <= 1'b0;
        end
    end
end

// Implement axi_awaddr latching
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awaddr <= 0;
    end
  else
    begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
        begin
          axi_awaddr <= S_AXI_AWADDR;
        end
    end
end

// Implement axi_wready generation
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end
  else
    begin
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
        begin
          axi_wready <= 1'b1;
        end
      else
        begin
          axi_wready <= 1'b0;
        end
    end
end

// Implement memory mapped register select and write logic generation
assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      control_reg <= 32'h00190003;  // Default: mode=3, clk_scale=25 (100MHz/25=4MHz)
      config_reg <= 32'h00000101;   // Default: cs_inactive=1, tx_count=1
      tx_data_reg <= 0;
    end
  else begin
    if (slv_reg_wren)
      begin
        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
          4'h0:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                control_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
              end
          4'h1:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                config_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
              end
          4'h2:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                tx_data_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
              end
          default : begin
                      control_reg <= control_reg;
                      config_reg <= config_reg;
                      tx_data_reg <= tx_data_reg;
                    end
        endcase
      end
  end
end

// Implement write response logic generation
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end
  else
    begin
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
        begin
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0;
        end
      else
        begin
          if (S_AXI_BREADY && axi_bvalid)
            begin
              axi_bvalid <= 1'b0;
            end
        end
    end
end

// Implement axi_arready generation
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end
  else
    begin
      if (~axi_arready && S_AXI_ARVALID)
        begin
          axi_arready <= 1'b1;
          axi_araddr  <= S_AXI_ARADDR;
        end
      else
        begin
          axi_arready <= 1'b0;
        end
    end
end

// Implement axi_rvalid generation
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end
  else
    begin
      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
        begin
          axi_rvalid <= 1'b1;
          axi_rresp  <= 2'b0;
        end
      else if (axi_rvalid && S_AXI_RREADY)
        begin
          axi_rvalid <= 1'b0;
        end
    end
end

// Implement memory mapped register select and read logic generation
assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

always @(*)
begin
      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
        4'h0   : reg_data_out <= control_reg;
        4'h1   : reg_data_out <= config_reg;
        4'h2   : reg_data_out <= tx_data_reg;
        4'h3   : reg_data_out <= rx_data_reg;
        4'h4   : reg_data_out <= status_reg;
        default : reg_data_out <= 0;
      endcase
end

// Output register or memory read data
always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_rdata  <= 0;
    end
  else
    begin
      if (slv_reg_rden)
        begin
          axi_rdata <= reg_data_out;
        end
    end
end

// Generate TX data valid pulse when TX_DATA_REG is written
reg tx_data_written;
always @(posedge S_AXI_ACLK)
begin
  if (S_AXI_ARESETN == 1'b0)
    begin
      o_tx_dv <= 1'b0;
      tx_data_written <= 1'b0;
    end
  else
    begin
      // Detect write to TX_DATA_REG
      if (slv_reg_wren && (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 4'h2))
        begin
          tx_data_written <= 1'b1;
        end
      else
        begin
          tx_data_written <= 1'b0;
        end

      // Generate one-cycle pulse
      o_tx_dv <= tx_data_written;
    end
end

// Capture RX data when received
always @(posedge S_AXI_ACLK)
begin
  if (S_AXI_ARESETN == 1'b0)
    begin
      rx_data_reg <= 0;
    end
  else
    begin
      if (i_rx_dv)
        begin
          rx_data_reg[7:0] <= i_rx_byte;
        end
    end
end

// Update status register
always @(posedge S_AXI_ACLK)
begin
  if (S_AXI_ARESETN == 1'b0)
    begin
      status_reg <= 0;
    end
  else
    begin
      status_reg[0] <= i_tx_ready;
      status_reg[1] <= i_rx_dv;
      status_reg[11:8] <= i_rx_count;
    end
end

// Connect outputs to registers
assign o_spi_mode = control_reg[1:0];
assign o_clk_scale = control_reg[31:16];
assign o_cs_inactive_clks = config_reg[2:0];
assign o_tx_count = config_reg[12:8];
assign o_tx_byte = tx_data_reg[7:0];

endmodule
