/* Copyright 2023-2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   A Femto-BIO CPU instance, with APB interface.
   A 16-bit wide RAM internal to this instance is used for instruction/stack memory. */

`default_nettype none

module femto_bio #(parameter RAM_BITS=10) (
    input clk,
    input rst_n

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

    FemtoRV32 i_femtorv(
        .clk(clk),
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
        .resetn(rst_n)
    );

    femto_ram #(.RAM_BITS(RAM_BITS)) i_femtoram (
        .clk(clk),
        .rst_n(rst_n),
        .rstrb(femto_rstrb),
        .rinstr(femto_rinstr),
        .wstrb(femto_wstrb),
        .mask(femto_mask),
        .addr(femto_addr[RAM_BITS-1:0]),
        .half(femto_half),
        .rbusy(femto_rbusy),
        .wbusy(femto_wbusy),
        .data_in(femto_wdata),
        .data_out(femto_rdata)
    );

endmodule
