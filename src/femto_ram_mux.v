/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   RAM mux for APB/core access to Femto RAM */

module femto_ram_mux #(parameter RAM_WIDTH=10) (
    input clk,
    input rst_n,

    // APB interface
    input  [RAM_WIDTH-1:0] paddr,
    input         psel,
    input         penable,
    input         pwrite,
    input  [31:0] pwdata,
    output [31:0] prdata,
    output        pready,

    // Femto core interface
    input core_rstrb,    // High to request a read
    input core_rinstr,   // High on instruction fetch - in this case
                    // the data at addr + 4 is cached after this
                    // read completes so it is available for the 
                    // next instruction fetch

    input core_wstrb,    // High to request a write
    input [3:0] core_mask,  // Byte-enable mask for writes

    input [RAM_WIDTH-1:0] core_addr,  // Address, low 2 bits should be 0 for word (32-bit) accesses.
    input core_half,            // High if accessing a half-word (16 bits), 
                                // in this case data_out has high and low halfs equal
                                // and address bit 1 controls which half word is read.

    output core_rbusy,      // High while a read is in progress
    output core_wbusy,      // High while a write is in progress
    
    input  [31:0] core_wdata,
    output [31:0] core_rdata,

    // Femto RAM interface
    output ram_rstrb,    // High to request a read
    output ram_rinstr,   // High on instruction fetch - in this case
                    // the data at addr + 4 is cached after this
                    // read completes so it is available for the 
                    // next instruction fetch

    output ram_wstrb,    // High to request a write
    output [3:0] ram_mask,  // Byte-enable mask for writes

    output [RAM_WIDTH-1:0] ram_addr,  // Address, low 2 bits should be 0 for word (32-bit) accesses.
    output ram_half,            // High if accessing a half-word (16 bits), 
                                // in this case data_out has high and low halfs equal
                                // and address bit 1 controls which half word is read.

    input ram_rbusy,      // High while a read is in progress
    input ram_wbusy,      // High while a write is in progress
    
    output [31:0] ram_wdata,
    input  [31:0] ram_rdata

);

    reg sel_core;

    always @(posedge clk) begin
        if (~rst_n)
            sel_core <= 1;
        else begin
            if ((sel_core & !(ram_rbusy | ram_wbusy)) ||
                (!sel_core & !psel))
            begin
                if (psel)
                    sel_core <= 0;
                else
                    sel_core <= 1;
            end
        end
    end

    reg core_rstrb_r;
    reg core_wstrb_r;
    always @(posedge clk) begin
        if (~rst_n) begin
            core_rstrb_r <= 0;
            core_wstrb_r <= 0;
        end else begin
            if (!sel_core) begin
                core_rstrb_r <= core_rstrb_r | core_rstrb;
                core_wstrb_r <= core_wstrb_r | core_wstrb;
            end else begin
                core_rstrb_r <= 0;
                core_wstrb_r <= 0;
            end
        end
    end

    reg apb_in_progress;
    reg psel_r;
    always @(posedge clk) begin
        if (~rst_n) begin
            apb_in_progress <= 0;
            psel_r <= 0;
        end else begin
            psel_r <= psel;
            if (!sel_core & psel & penable & !apb_in_progress) begin
                apb_in_progress <= 1;
            end else if (!(ram_rbusy | ram_wbusy)) begin
                apb_in_progress <= 0;
            end
        end
    end

    assign ram_rstrb = sel_core ? (core_rstrb | core_rstrb_r) : psel & penable & ~pwrite & ~apb_in_progress;
    assign ram_rinstr = sel_core ? core_rinstr : 1'b0;
    assign ram_wstrb = sel_core ? (core_wstrb | core_wstrb_r) : psel & penable & pwrite & ~apb_in_progress;
    assign ram_mask = sel_core ? core_mask : 4'b1111;
    assign ram_addr = sel_core ? core_addr : paddr;
    assign ram_half = sel_core ? core_half : 1'b0;
    assign ram_wdata = sel_core ? core_wdata : pwdata;

    assign core_rbusy = sel_core ? ram_rbusy : 1'b1;
    assign core_wbusy = sel_core ? ram_wbusy : 1'b1;
    assign core_rdata = ram_rdata;

    assign pready = sel_core ? 1'b0 : apb_in_progress & !(ram_rbusy | ram_wbusy);
    assign prdata = ram_rdata;

endmodule