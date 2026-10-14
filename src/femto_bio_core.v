/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   A Femto-BIO CPU instance.
   A 16-bit wide RAM internal to this instance is used for instruction/stack memory. */

`default_nettype none

module femto_bio_core #(parameter RAM_WIDTH=10) (
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input clk,
    input rst_n,

    output reg [31:0] gpio_data_out,
    output reg [31:0] gpio_mask_out,
    output reg        gpio_set_out,
    output reg        gpio_set_oe,
    input  [31:0] gpio_in

);

    wire [31:0] femto_addr;
    wire [31:0] femto_wdata;
    wire [31:0] femto_rdata;
    wire  [3:0] femto_mask;
    wire        femto_half;
    wire        femto_wstrb;
    wire        femto_rstrb;
    wire        femto_rinstr;
    wire        femto_rbusy;
    wire        femto_wbusy;

    wire [4:0]  femto_rd_id;
    wire [31:0] femto_rd_wdata;
    wire [4:0]  femto_rs1_id;
    wire [4:0]  femto_rs2_id;
    wire [31:0] femto_rs1_rdata;
    wire [31:0] femto_rs2_rdata;
    wire        femto_rd_write;
    wire        femto_rs1_read;
    wire        femto_rs2_read;
    wire        femto_reg_wbusy = 1'b0;
    wire        femto_reg_rbusy = 1'b0;

    reg [31:0] gpio_action_mask;

    FemtoRV32 #(.PC_WIDTH(RAM_WIDTH)) i_femtorv(
        .clk(clk),
        .resetn(rst_n),

        .mem_addr(femto_addr),
        .mem_wdata(femto_wdata),
        .mem_wstrb(femto_wstrb),
        .mem_mask(femto_mask),
        .mem_half(femto_half),
        .mem_rdata(femto_rdata),
        .mem_rstrb(femto_rstrb),
        .mem_rinstr(femto_rinstr),
        .mem_rbusy(femto_rbusy),
        .mem_wbusy(femto_wbusy),

        .rd_id(femto_rd_id),      // Destination register for access to x16+
        .rd_wdata(femto_rd_wdata),
        .rs1_id(femto_rs1_id),     // Source register 1 for access to x16+
        .rs2_id(femto_rs2_id),     // Source register 2 for access to x16+
        .rs1_rdata(femto_rs1_rdata),
        .rs2_rdata(femto_rs2_rdata),
        .rd_write(femto_rd_write),   // asserted if the destination register is being written
        .rs1_read(femto_rs1_read),   // asserted if source register 1 is being read
        .rs2_read(femto_rs2_read),   // asserted if source register 2 is being read
        .reg_wbusy(femto_reg_wbusy),  // asserted while register write should block
        .reg_rbusy(femto_reg_rbusy)   // asserted while register read should block
    );

    femto_ram #(.RAM_WIDTH(RAM_WIDTH)) i_femtoram (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .clk(clk),
        .rst_n(rst_n),
        .rstrb(femto_rstrb),
        .rinstr(femto_rinstr),
        .wstrb(femto_wstrb),
        .mask(femto_mask),
        .addr(femto_addr[RAM_WIDTH-1:0]),
        .half(femto_half),
        .rbusy(femto_rbusy),
        .wbusy(femto_wbusy),
        .data_in(femto_wdata),
        .data_out(femto_rdata)
    );

    // GPIO handling
    function [31:0] gpio_rdata(input [4:0] reg_id);
        begin
            case (reg_id)
            // x21 read: gpio pins -> x21
            5'd21: gpio_rdata = gpio_in;

            // x26 read: gpio action mask -> x26
            5'd26: gpio_rdata = gpio_action_mask;

            default: gpio_rdata = 32'b0;
            endcase
        end
    endfunction

    assign femto_rs1_rdata = gpio_rdata(femto_rs1_id);
    assign femto_rs2_rdata = gpio_rdata(femto_rs2_id);

    wire [31:0] masked_gpio_set = femto_rd_wdata & gpio_action_mask;
    wire [31:0] masked_gpio_clear = ~femto_rd_wdata & gpio_action_mask;

    always @(posedge clk) begin
        if (!rst_n) begin
            gpio_action_mask <= 32'b0;
        end
        else if (femto_rd_write) begin
            case (femto_rd_id)

            // x26 write: update the gpio action mask
            5'd26: gpio_action_mask <= femto_rd_wdata;

            default: ;
            endcase
        end
    end

    always @(*) begin
        gpio_set_out = 1'b0;
        gpio_set_oe = 1'b0;

        case (femto_rd_id)
            // x21 write: (x26 & x21) -> gpio pins
            5'd21: begin
                gpio_data_out = femto_rd_wdata;
                gpio_mask_out = gpio_action_mask;
                gpio_set_out = 1'b1;
            end

            // x22 write: (x26 & x22) -> a `1` in x22 will set corresponding pin on gpio
            5'd22: begin
                gpio_data_out = 32'hffffffff;
                gpio_mask_out = masked_gpio_set;
                gpio_set_out = 1'b1;
            end

            // TODO: Maybe change this to a regular set pattern - I'm not convinced this oddity in the BIO design is useful.
            // x23 write: (x26 & ~x23) -> a `0` in x23 will clear corresponding pin on gpio
            5'd23: begin
                gpio_data_out = 32'b0;
                gpio_mask_out = masked_gpio_clear;
                gpio_set_out = 1'b1;
            end

            // x24 write: (x26 & x24) -> a `1` in x24 will make corresponding gpio pin an output
            5'd24: begin
                gpio_data_out = 32'hffffffff;
                gpio_mask_out = masked_gpio_set;
                gpio_set_oe = 1'b1;
            end

            // x25 write: (x26 & x25) -> a `1` in x25 will make corresponding gpio pin an input
            5'd25: begin
                gpio_data_out = 32'b0;
                gpio_mask_out = masked_gpio_set;
                gpio_set_oe = 1'b1;
            end

            default: begin
                gpio_data_out = 32'b0;
                gpio_mask_out = 32'b0;
            end
        endcase
    end

endmodule
