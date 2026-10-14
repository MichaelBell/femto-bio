/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   RAM module for Femto BIO CPU */

// Register file using latches on gf180, this is currently WIP.

`default_nettype none

`ifndef SYNTH_FPGA

module femto_register (
    input  wire clk,
    input  wire rst,
    input  wire [31:0] wdata,
    input  wire we,
    output wire [31:0] rdata
);

    wire gated_clk;
    
    gf180mcu_fd_sc_mcu7t5v0__icgtp_1 i_clkgate (
        .CLK(clk),
        .E(we),
        .TE(rst),
        .Q(gated_clk)
    );

    generate
    genvar i;
    for (i = 0; i < 32; i = i + 1) begin : reg_loop
        gf180mcu_as_sc_mcu7t3v3__dlxtp_2 i_reg (
            .D(wdata[i]),
            .ENA(gated_clk),
            .Q(rdata[i])
        );
    end
    endgenerate

endmodule

`endif

module femto_reg_file (
    input  wire clk,
    input  wire rst_n,
    input  wire [3:0] rs1_id,
    input  wire [3:0] rs2_id,
    input  wire [3:0] rd_id,
    input  wire [31:0] rd_wdata,
    input  wire we,
    output wire [31:0] rs1,
    output wire [31:0] rs2
);

`ifdef SYNTH_FPGA

    reg [31:0] registerFile [15:0];

    always @(posedge clk) begin
        if (we && rd_id != 0)
            registerFile[rd_id] <= rd_wdata;
    end

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1)
            registerFile[i] = 0;
    end    

    assign rs1 = registerFile[rs1_id];
    assign rs2 = registerFile[rs2_id];

`else

    reg [31:0] wdata;
    reg rst;
    always @(posedge clk) begin
        if (~rst_n) begin
            wdata <= 32'b0;
            rst <= 1'b1;
        end
        else if (we) begin
            wdata <= rd_wdata;
            rst <= 1'b0;
        end
    end

    wire [31:0] rdata [15:0];

    assign rdata[0] = 32'b0;

    generate
    for (genvar i = 1; i < 16; i = i + 1) begin : reg_loop
        femto_register i_reg (
            .clk(clk),
            .rst(rst),
            .wdata(wdata),
            .we(we && rd_id == i),
            .rdata(rdata[i])
        );
    end
    endgenerate

    assign rs1 = rdata[rs1_id];
    assign rs2 = rdata[rs2_id];

`endif

endmodule
