/* Copyright 2023-2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   A Femto-BIO CPU instance, with APB interface.
   A 16-bit wide RAM internal to this instance is used for instruction/stack memory. */

`default_nettype none

module RV4028_femtorv #(parameter RAM_BITS=10) (
    input clk,
    input rst_n,

    // TODO add APB interface
    output [31:0] addr,
);

    wire [31:0] femto_addr;
    wire [31:0] femto_wdata;
    wire [31:0] femto_rdata;
    wire  [3:0] femto_mask;
    wire        femto_half;
    wire        femto_wnext;
    wire        femto_wstrb;
    wire        femto_rstrb;
    wire        femto_rbusy;
    wire        femto_wbusy;

    FemtoRV32 i_femtorv(
        .clk(clk),
        .mem_addr(femto_addr),
        .mem_wdata(femto_wdata),
        .mem_wnext(femto_wnext),
        .mem_wstrb(femto_wstrb),
        .mem_mask(femto_mask),
        .mem_half(femto_half),
        .mem_rdata(femto_rdata),
        .mem_rstrb(femto_rstrb),
        .mem_rbusy(femto_rbusy),
        .mem_wbusy(femto_wbusy),
        .interrupt_request(!int_n),
        .resetn(rst_n)
    );

    // TODO fix all this
    wire [15:0] data_from_ram;
    wire [15:0] data_to_ram;
    wire        ram_we;
    reg [15:0] buffered_rdata;
    reg  [1:0] read_cycle;
    reg  [1:0] write_cycle;
    wire       read_in_progress;
    wire       write_in_progress;
    wire       read_finishing;
    wire       write_finishing;
    wire       is_ram_addr;
    wire [31:0] rdata;
    assign rdata = {data_from_ram, read_cycle[1] ? buffered_rdata : data_from_ram};
    assign femto_rbusy = femto_rstrb || (read_in_progress && !read_finishing);
    assign femto_wbusy = femto_wstrb || (write_in_progress && !write_finishing);
    assign rd_n = !(femto_rstrb || read_in_progress);
    assign wr_n = !(femto_wstrb || write_cycle == 2'b10);

    assign read_in_progress = |read_cycle;
    assign write_in_progress = |write_cycle;

    assign read_finishing = read_cycle[0] && wait_n_r && (femto_half || read_cycle[1]);
    assign write_finishing = write_cycle[0] && (femto_half || write_cycle[1]);

    assign is_ram_addr = (femto_addr[31:RAM_BITS] == 0);
    assign femto_rdata = is_ram_addr ? rdata : data_in;

    always @(posedge clk) begin
        if (!rst_n) begin
            read_cycle <= 0;
        end else begin
            if (femto_rstrb || read_in_progress) begin
                if (!(!wait_n_r && read_cycle[0])) begin
                    read_cycle <= read_cycle + 1;
                end
                if (read_cycle[0]) begin
                    buffered_rdata <= rdata;
                end
                if (read_finishing) begin
                    read_cycle <= 0;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            write_cycle <= 0;
        end else begin
            if (femto_wstrb || write_in_progress) begin
                write_cycle <= write_cycle + 1;
                if (write_finishing) begin
                    write_cycle <= 0;
                end
            end
        end
    end

    wire addr1 = femto_half ? femto_addr[1] : (read_cycle[1] | write_cycle[1]);
    assign addr = {femto_addr[31:2], addr1, 1'b0};
    assign msk_n = addr1 ? ~femto_mask[3:2] : ~femto_mask[1:0];

    assign data_out = addr1 ? femto_wdata[31:16] : femto_wdata[15:0];
    assign data_oe = write_cycle[0];

    // TODO APB interface to RAM
    rv4028_ram i_ram(
        .clk(clk),
        .wen(ram_we),
        .addr(addr[RAM_BITS-1:1]),
        .data_in(data_to_ram),
        .data_out(data_from_ram)
    );

    // TODO release femto from reset over APB

    // TODO all the BIO stuff

    wire unused = &{1'b0, femto_addr[0]};

endmodule
