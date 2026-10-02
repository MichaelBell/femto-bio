`default_nettype none

module tb ();

    wire clk;
    wire rst_n;

   wire [31:0] mem_addr;  // address bus
   wire [31:0] mem_wdata; // data to be written
   wire        mem_wstrb; // active to initiate a memory write
   wire  [3:0] mem_mask;  // read/write mask for the 4 bytes of each word
   wire        mem_half;  // active for 8 or 16-bit read/writes

   wire  [31:0] mem_rdata; // wire lines for both data and instr
   wire        mem_rstrb; // active to initiate memory read
   wire        mem_rinstr; // active to indicate instruction fetch
   wire         mem_rbusy; // asserted if memory is busy reading value
   wire         mem_wbusy; // asserted if memory is busy writing value

   wire  [4:0] rd_id;      // Destination register for access to x16+
   wire [31:0] rd_wdata;   // Data to be written to the destination register
   wire  [4:0] rs1_id;     // Source register 1 for access to x16+
   wire  [4:0] rs2_id;     // Source register 2 for access to x16+
   wire  [31:0] rs1_rdata;  // Data returned for source register 1
   wire  [31:0] rs2_rdata;  // Data returned for source register 2
   wire        rd_write;   // asserted if the destination register is being written
   wire        rs1_read;   // asserted if source register 1 is being read
   wire        rs2_read;   // asserted if source register 2 is being read
   wire         reg_wbusy;  // asserted while register write should block
   wire         reg_rbusy;   // asserted while register read should block
    
    FemtoRV32 dut (
        .clk(clk),
        .resetn(rst_n),

        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_mask(mem_mask),
        .mem_half(mem_half),

        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rinstr(mem_rinstr),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),

        .rd_id(rd_id),
        .rd_wdata(rd_wdata),
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rs1_rdata(rs1_rdata),
        .rs2_rdata(rs2_rdata),
        .rd_write(rd_write),
        .rs1_read(rs1_read),
        .rs2_read(rs2_read),
        .reg_wbusy(reg_wbusy),
        .reg_rbusy(reg_rbusy)
    );

endmodule